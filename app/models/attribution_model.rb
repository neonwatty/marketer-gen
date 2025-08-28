class AttributionModel < ApplicationRecord
  belongs_to :user
  belongs_to :touchpoint
  belongs_to :journey

  MODEL_TYPES = %w[first_touch last_touch linear time_decay position_based data_driven custom].freeze

  validates :model_type, presence: true, inclusion: { in: MODEL_TYPES }
  validates :attribution_percentage, presence: true,
           numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :conversion_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :confidence_score, numericality: { in: 0.0..1.0 }, allow_nil: true

  serialize :calculation_metadata, coder: JSON
  serialize :algorithm_parameters, coder: JSON

  scope :by_model_type, ->(type) { where(model_type: type) }
  scope :by_journey, ->(journey_id) { where(journey_id: journey_id) }
  scope :high_confidence, -> { where("confidence_score >= ?", 0.7) }
  scope :with_conversion_value, -> { where.not(conversion_value: nil) }

  before_validation :calculate_attribution_percentage, on: :create
  before_validation :set_confidence_score, on: :create

  def attribution_credit
    return 0 unless conversion_value && attribution_percentage
    (conversion_value * attribution_percentage / 100.0).round(2)
  end

  def weighted_attribution_score
    base_score = attribution_percentage / 100.0
    confidence_multiplier = confidence_score || 0.5
    touchpoint_weight = touchpoint.channel_attribution_score

    (base_score * confidence_multiplier * touchpoint_weight).round(4)
  end

  def channel_name
    touchpoint.channel
  end

  def touchpoint_type
    touchpoint.touchpoint_type
  end

  def touchpoint_timestamp
    touchpoint.occurred_at
  end

  def journey_position
    touchpoint.journey_position
  end

  def time_to_conversion
    return nil unless journey.touchpoints.conversions.exists?

    conversion_touchpoint = journey.touchpoints.conversions.order(:occurred_at).last
    return nil unless conversion_touchpoint

    ((conversion_touchpoint.occurred_at - touchpoint.occurred_at) / 1.hour).round(2)
  end

  def attribution_analysis
    {
      model_type: model_type,
      attribution_percentage: attribution_percentage,
      attribution_credit: attribution_credit,
      confidence_score: confidence_score,
      weighted_score: weighted_attribution_score,
      channel: channel_name,
      touchpoint_type: touchpoint_type,
      journey_position: journey_position,
      time_to_conversion: time_to_conversion,
      calculation_metadata: calculation_metadata
    }
  end

  def self.aggregate_by_channel(attributions)
    attributions.group_by(&:channel_name).transform_values do |channel_attributions|
      {
        total_credit: channel_attributions.sum(&:attribution_credit),
        average_percentage: (channel_attributions.sum(&:attribution_percentage) / channel_attributions.count.to_f).round(2),
        touchpoint_count: channel_attributions.count,
        average_confidence: (channel_attributions.sum(&:confidence_score) / channel_attributions.count.to_f).round(3),
        weighted_score: channel_attributions.sum(&:weighted_attribution_score).round(4)
      }
    end
  end

  def self.model_comparison(journey_id)
    journey_attributions = where(journey_id: journey_id)

    MODEL_TYPES.map do |model_type|
      type_attributions = journey_attributions.where(model_type: model_type)
      next if type_attributions.empty?

      {
        model_type: model_type,
        total_credit: type_attributions.sum(&:attribution_credit),
        channel_distribution: aggregate_by_channel(type_attributions),
        average_confidence: (type_attributions.sum(&:confidence_score) / type_attributions.count.to_f).round(3),
        touchpoint_coverage: type_attributions.count
      }
    end.compact
  end

  private

  def calculate_attribution_percentage
    return if attribution_percentage.present?

    service = AttributionModelingService.new(journey)
    self.attribution_percentage = service.calculate_attribution_for_touchpoint(touchpoint, model_type)
  end

  def set_confidence_score
    return if confidence_score.present?

    # Calculate confidence based on touchpoint position, timing, and channel effectiveness
    position_score = calculate_position_confidence
    timing_score = calculate_timing_confidence
    channel_score = touchpoint.channel_attribution_score

    self.confidence_score = ((position_score + timing_score + channel_score) / 3.0).round(4)
  end

  def calculate_position_confidence
    total_touchpoints = journey.touchpoints.count
    return 0.5 if total_touchpoints <= 1

    position = touchpoint.journey_position

    case model_type
    when "first_touch"
      position == 1 ? 1.0 : 0.2
    when "last_touch"
      position == total_touchpoints ? 1.0 : 0.2
    when "linear"
      0.7 # Linear gives equal weight, so confidence is consistent
    when "position_based"
      [ 1, total_touchpoints ].include?(position) ? 0.9 : 0.6
    when "time_decay"
      # More recent touchpoints get higher confidence
      decay_factor = (total_touchpoints - position + 1).to_f / total_touchpoints
      [ decay_factor, 0.3 ].max
    else
      0.6
    end
  end

  def calculate_timing_confidence
    time_gap = touchpoint.time_since_previous_touchpoint
    return 0.6 unless time_gap

    # Confidence decreases with large time gaps
    case time_gap
    when 0..1 then 0.9
    when 1..6 then 0.8
    when 6..24 then 0.7
    when 24..168 then 0.6
    else 0.4
    end
  end
end
