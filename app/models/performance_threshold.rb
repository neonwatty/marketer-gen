# frozen_string_literal: true

# == Schema Information
#
# Table name: performance_thresholds
#
#  id                             :integer          not null, primary key
#  accuracy_score                 :decimal(5, 4)
#  anomaly_threshold              :decimal(15, 6)
#  audience_segment               :string
#  auto_adjust                    :boolean          default(TRUE)
#  baseline_end_date              :datetime
#  baseline_mean                  :decimal(15, 6)
#  baseline_start_date            :datetime
#  baseline_std_dev               :decimal(15, 6)
#  confidence_level               :decimal(5, 4)    default(0.95)
#  context_filters                :string           not null
#  day_of_week_segment            :string
#  f1_score                       :decimal(5, 4)
#  false_negatives                :integer          default(0)
#  false_positives                :integer          default(0)
#  last_recalculated_at           :datetime
#  learning_rate                  :decimal(5, 4)    default(0.1)
#  lower_threshold                :decimal(15, 6)
#  metric_source                  :string           not null
#  metric_type                    :string           not null
#  model_parameters               :json
#  precision_score                :decimal(5, 4)
#  recall_score                   :decimal(5, 4)
#  recalculation_frequency_hours  :integer          default(24)
#  sample_size                    :integer
#  seasonality_segment            :string
#  time_of_day_segment            :string
#  true_negatives                 :integer          default(0)
#  true_positives                 :integer          default(0)
#  upper_threshold                :decimal(15, 6)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  campaign_id                    :integer
#  journey_id                     :integer
#
# Indexes
#
#  index_performance_thresholds_on_accuracy_score_and_metric_type    (accuracy_score,metric_type)
#  index_performance_thresholds_on_campaign_id                       (campaign_id)
#  index_performance_thresholds_on_context_filters                   (context_filters)
#  index_performance_thresholds_on_journey_id                        (journey_id)
#  idx_on_last_recalculated_at_auto_adjust_7ccd367fa2                (last_recalculated_at,auto_adjust)
#  index_performance_thresholds_on_metric_type_and_metric_source     (metric_type,metric_source)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#  fk_rails_...  (journey_id => journeys.id)
#

class PerformanceThreshold < ApplicationRecord
  belongs_to :campaign, optional: true
  belongs_to :journey, optional: true

  # Validations
  validates :metric_type, presence: true
  validates :metric_source, presence: true
  validates :context_filters, presence: true
  validates :confidence_level, presence: true,
            numericality: { greater_than_or_equal_to: 0.5, less_than_or_equal_to: 1.0 }
  validates :learning_rate, presence: true,
            numericality: { greater_than_or_equal_to: 0.001, less_than_or_equal_to: 1.0 }
  validates :recalculation_frequency_hours, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 168 } # Max 1 week
  validates :sample_size, numericality: { greater_than: 0 }, allow_blank: true

  validate :validate_threshold_values
  validate :validate_model_performance_scores
  validate :validate_confusion_matrix_values
  validate :validate_baseline_dates

  # Scopes
  scope :for_metric, ->(type, source) { where(metric_type: type, metric_source: source) }
  scope :auto_adjustable, -> { where(auto_adjust: true) }
  scope :need_recalculation, -> {
    where(auto_adjust: true)
      .where("last_recalculated_at IS NULL OR last_recalculated_at < ?",
             ->(threshold) { threshold.recalculation_frequency_hours.hours.ago })
  }
  scope :high_accuracy, -> { where("accuracy_score > ?", 0.8) }
  scope :recent, -> { where("created_at > ?", 30.days.ago) }
  scope :for_context, ->(filters) { where(context_filters: filters.to_json) }
  scope :for_campaign, ->(campaign) { where(campaign: campaign) }
  scope :for_journey, ->(journey) { where(journey: journey) }

  # Callbacks
  before_validation :set_defaults
  before_save :parse_context_filters
  after_create :schedule_initial_calculation
  after_update :schedule_recalculation, if: :should_recalculate?

  # Constants
  MIN_SAMPLE_SIZE = 100
  MAX_BASELINE_PERIOD_DAYS = 365
  DEFAULT_SEGMENTS = {
    time_of_day: %w[morning afternoon evening night],
    day_of_week: %w[weekday weekend],
    seasonality: %w[high_season low_season holiday_season]
  }.freeze

  # Instance Methods
  def context_filters_hash
    @context_filters_hash ||= JSON.parse(context_filters)
  rescue JSON::ParserError
    {}
  end

  def context_filters_hash=(hash)
    self.context_filters = hash.to_json
    @context_filters_hash = hash
  end

  def needs_recalculation?
    return true if last_recalculated_at.nil?
    return false unless auto_adjust?

    last_recalculated_at < recalculation_frequency_hours.hours.ago
  end

  def sufficient_sample_size?
    sample_size.present? && sample_size >= MIN_SAMPLE_SIZE
  end

  def baseline_period_valid?
    baseline_start_date.present? && baseline_end_date.present? &&
      baseline_start_date < baseline_end_date &&
      (baseline_end_date - baseline_start_date).to_i <= MAX_BASELINE_PERIOD_DAYS.days
  end

  def model_performance_acceptable?
    accuracy_score.present? && accuracy_score > 0.7 &&
      precision_score.present? && precision_score > 0.6 &&
      recall_score.present? && recall_score > 0.6
  end

  def is_anomaly?(value, context = {})
    return false unless anomaly_threshold.present?

    # Calculate z-score if we have baseline statistics
    if baseline_mean.present? && baseline_std_dev.present? && baseline_std_dev > 0
      z_score = (value - baseline_mean) / baseline_std_dev
      anomaly_score = 1 - Math.exp(-0.5 * z_score ** 2) / Math.sqrt(2 * Math::PI)

      anomaly_score > (1 - confidence_level)
    else
      # Fallback to simple threshold comparison
      (value - anomaly_threshold).abs > (anomaly_threshold * 0.1)
    end
  end

  def calculate_anomaly_score(value)
    return 0.0 unless baseline_mean.present? && baseline_std_dev.present? && baseline_std_dev > 0

    z_score = (value - baseline_mean) / baseline_std_dev

    # Convert z-score to anomaly probability (0-1 scale)
    probability = 1 - Math.exp(-0.5 * z_score.abs)
    [ probability, 1.0 ].min
  end

  def update_baseline_statistics!(data_points)
    return false if data_points.empty?

    values = data_points.map(&:to_f)

    self.sample_size = values.length
    self.baseline_mean = values.sum / values.length
    self.baseline_std_dev = calculate_standard_deviation(values, baseline_mean)

    # Calculate thresholds based on confidence level
    z_score = calculate_z_score_for_confidence(confidence_level)
    margin = z_score * baseline_std_dev

    self.upper_threshold = baseline_mean + margin
    self.lower_threshold = baseline_mean - margin
    self.anomaly_threshold = baseline_mean + (2 * baseline_std_dev) # 2-sigma rule

    self.baseline_start_date = data_points.first.try(:created_at) || 30.days.ago
    self.baseline_end_date = data_points.last.try(:created_at) || Time.current
    self.last_recalculated_at = Time.current

    save!

    Rails.logger.info "Updated baseline statistics for threshold #{id}: " \
                      "mean=#{baseline_mean}, std_dev=#{baseline_std_dev}, " \
                      "upper=#{upper_threshold}, lower=#{lower_threshold}"

    true
  rescue StandardError => e
    Rails.logger.error "Error updating baseline statistics for threshold #{id}: #{e.message}"
    false
  end

  def update_model_performance!(predictions, actual_values, threshold_value = nil)
    return false if predictions.length != actual_values.length || predictions.empty?

    threshold_value ||= upper_threshold || baseline_mean
    return false unless threshold_value

    # Calculate confusion matrix
    tp = fp = tn = fn = 0

    predictions.zip(actual_values).each do |predicted, actual|
      predicted_anomaly = predicted > threshold_value
      actual_anomaly = actual > threshold_value

      if predicted_anomaly && actual_anomaly
        tp += 1
      elsif predicted_anomaly && !actual_anomaly
        fp += 1
      elsif !predicted_anomaly && !actual_anomaly
        tn += 1
      else
        fn += 1
      end
    end

    # Update confusion matrix counters
    self.true_positives += tp
    self.false_positives += fp
    self.true_negatives += tn
    self.false_negatives += fn

    # Calculate performance metrics
    calculate_performance_metrics

    # Adaptive learning: adjust thresholds based on performance
    if auto_adjust? && model_performance_acceptable?
      adapt_thresholds_based_on_performance
    end

    save!

    Rails.logger.info "Updated model performance for threshold #{id}: " \
                      "accuracy=#{accuracy_score}, precision=#{precision_score}, " \
                      "recall=#{recall_score}, f1=#{f1_score}"

    true
  rescue StandardError => e
    Rails.logger.error "Error updating model performance for threshold #{id}: #{e.message}"
    false
  end

  def mark_false_positive!
    self.false_positives += 1
    calculate_performance_metrics

    # Adjust threshold to reduce false positives
    if auto_adjust? && false_positive_rate > 0.1
      self.upper_threshold = upper_threshold * (1 + learning_rate)
      self.anomaly_threshold = anomaly_threshold * (1 + learning_rate)
    end

    save!
  end

  def mark_false_negative!
    self.false_negatives += 1
    calculate_performance_metrics

    # Adjust threshold to reduce false negatives
    if auto_adjust? && false_negative_rate > 0.1
      self.upper_threshold = upper_threshold * (1 - learning_rate)
      self.anomaly_threshold = anomaly_threshold * (1 - learning_rate)
    end

    save!
  end

  def false_positive_rate
    return 0.0 if (false_positives + true_negatives) == 0
    false_positives.to_f / (false_positives + true_negatives)
  end

  def false_negative_rate
    return 0.0 if (false_negatives + true_positives) == 0
    false_negatives.to_f / (false_negatives + true_positives)
  end

  def sensitivity # True Positive Rate / Recall
    recall_score || 0.0
  end

  def specificity # True Negative Rate
    return 0.0 if (true_negatives + false_positives) == 0
    true_negatives.to_f / (true_negatives + false_positives)
  end

  def reset_performance_counters!
    update!(
      true_positives: 0,
      false_positives: 0,
      true_negatives: 0,
      false_negatives: 0,
      accuracy_score: nil,
      precision_score: nil,
      recall_score: nil,
      f1_score: nil
    )
  end

  def self.find_or_create_for_context(metric_type, metric_source, context = {})
    context_filters = context.to_json

    threshold = find_by(
      metric_type: metric_type,
      metric_source: metric_source,
      context_filters: context_filters
    )

    return threshold if threshold

    create!(
      metric_type: metric_type,
      metric_source: metric_source,
      context_filters: context_filters,
      campaign_id: context[:campaign_id],
      journey_id: context[:journey_id],
      audience_segment: context[:audience_segment],
      time_of_day_segment: context[:time_of_day_segment],
      day_of_week_segment: context[:day_of_week_segment],
      seasonality_segment: context[:seasonality_segment]
    )
  end

  def self.cleanup_old_thresholds(older_than = 90.days)
    where("created_at < ? AND auto_adjust = ?", older_than.ago, false)
      .where("accuracy_score IS NULL OR accuracy_score < ?", 0.5)
      .delete_all
  end

  private

  def set_defaults
    self.model_parameters ||= {}
    self.confidence_level ||= 0.95
    self.learning_rate ||= 0.1
    self.recalculation_frequency_hours ||= 24
    self.auto_adjust = true if auto_adjust.nil?
  end

  def parse_context_filters
    if context_filters.is_a?(Hash)
      self.context_filters = context_filters.to_json
    elsif context_filters.blank?
      self.context_filters = "{}"
    end
  end

  def validate_threshold_values
    if upper_threshold.present? && lower_threshold.present? && upper_threshold <= lower_threshold
      errors.add(:upper_threshold, "must be greater than lower threshold")
    end

    if baseline_mean.present?
      if upper_threshold.present? && upper_threshold <= baseline_mean
        errors.add(:upper_threshold, "must be greater than baseline mean")
      end

      if lower_threshold.present? && lower_threshold >= baseline_mean
        errors.add(:lower_threshold, "must be less than baseline mean")
      end
    end
  end

  def validate_model_performance_scores
    %w[accuracy_score precision_score recall_score f1_score].each do |score_field|
      score = send(score_field)
      if score.present? && (score < 0.0 || score > 1.0)
        errors.add(score_field, "must be between 0.0 and 1.0")
      end
    end
  end

  def validate_confusion_matrix_values
    %w[true_positives false_positives true_negatives false_negatives].each do |field|
      value = send(field)
      if value.present? && value < 0
        errors.add(field, "must be non-negative")
      end
    end
  end

  def validate_baseline_dates
    return unless baseline_start_date.present? || baseline_end_date.present?

    if baseline_start_date.present? && baseline_end_date.present?
      if baseline_start_date >= baseline_end_date
        errors.add(:baseline_end_date, "must be after baseline start date")
      end

      period_days = (baseline_end_date - baseline_start_date).to_i
      if period_days > MAX_BASELINE_PERIOD_DAYS.days
        errors.add(:baseline_end_date, "baseline period cannot exceed #{MAX_BASELINE_PERIOD_DAYS} days")
      end
    elsif baseline_start_date.present? && baseline_end_date.blank?
      errors.add(:baseline_end_date, "must be present when baseline start date is set")
    elsif baseline_end_date.present? && baseline_start_date.blank?
      errors.add(:baseline_start_date, "must be present when baseline end date is set")
    end
  end

  def should_recalculate?
    saved_change_to_learning_rate? || saved_change_to_confidence_level? ||
      saved_change_to_auto_adjust? || saved_change_to_recalculation_frequency_hours?
  end

  def schedule_initial_calculation
    Analytics::Alerts::ThresholdCalculatorJob.perform_later(self)
  end

  def schedule_recalculation
    return unless auto_adjust?

    Analytics::Alerts::ThresholdCalculatorJob.set(
      wait: recalculation_frequency_hours.hours
    ).perform_later(self)
  end

  def calculate_standard_deviation(values, mean)
    return 0.0 if values.length < 2

    variance = values.sum { |v| (v - mean) ** 2 } / (values.length - 1)
    Math.sqrt(variance)
  end

  def calculate_z_score_for_confidence(confidence)
    # Approximate z-score for common confidence levels
    case confidence
    when 0.90..0.91 then 1.645
    when 0.95..0.96 then 1.96
    when 0.98..0.99 then 2.326
    when 0.99..1.0 then 2.576
    else
      # Linear approximation for other values
      1.645 + (confidence - 0.90) * (2.576 - 1.645) / 0.09
    end
  end

  def calculate_performance_metrics
    total_predictions = true_positives + false_positives + true_negatives + false_negatives
    return if total_predictions == 0

    # Accuracy
    self.accuracy_score = (true_positives + true_negatives).to_f / total_predictions

    # Precision
    precision_denominator = true_positives + false_positives
    self.precision_score = precision_denominator > 0 ? true_positives.to_f / precision_denominator : 0.0

    # Recall (Sensitivity)
    recall_denominator = true_positives + false_negatives
    self.recall_score = recall_denominator > 0 ? true_positives.to_f / recall_denominator : 0.0

    # F1 Score
    if precision_score > 0 && recall_score > 0
      self.f1_score = 2 * (precision_score * recall_score) / (precision_score + recall_score)
    else
      self.f1_score = 0.0
    end
  end

  def adapt_thresholds_based_on_performance
    # Adjust thresholds based on model performance and false positive/negative rates
    fp_rate = false_positive_rate
    fn_rate = false_negative_rate

    if fp_rate > 0.1 # Too many false positives - make thresholds more conservative
      adjustment_factor = 1 + (learning_rate * fp_rate)
      self.upper_threshold = upper_threshold * adjustment_factor if upper_threshold
      self.anomaly_threshold = anomaly_threshold * adjustment_factor if anomaly_threshold
    elsif fn_rate > 0.1 # Too many false negatives - make thresholds more sensitive
      adjustment_factor = 1 - (learning_rate * fn_rate)
      self.upper_threshold = upper_threshold * adjustment_factor if upper_threshold
      self.anomaly_threshold = anomaly_threshold * adjustment_factor if anomaly_threshold
    end

    # Ensure thresholds remain within reasonable bounds
    if baseline_mean.present? && baseline_std_dev.present?
      max_threshold = baseline_mean + (5 * baseline_std_dev)
      min_threshold = baseline_mean - (5 * baseline_std_dev)

      self.upper_threshold = [ upper_threshold, max_threshold ].min if upper_threshold
      self.lower_threshold = [ lower_threshold, min_threshold ].max if lower_threshold
    end
  end
end
