class BudgetAllocation < ApplicationRecord
  belongs_to :user
  belongs_to :campaign_plan, optional: true

  validates :name, presence: true, length: { maximum: 100 }
  validates :total_budget, presence: true, numericality: { greater_than: 0 }
  validates :allocated_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :channel_type, presence: true, inclusion: { in: %w[social_media email search display video content_marketing] }
  validates :time_period_start, presence: true
  validates :time_period_end, presence: true
  validates :optimization_objective, presence: true, inclusion: { in: %w[awareness engagement conversions revenue cost_efficiency] }
  
  validate :allocation_does_not_exceed_budget
  validate :time_period_is_valid
  validate :predictive_model_data_is_valid, if: :predictive_model_data?

  serialize :predictive_model_data, coder: JSON
  serialize :performance_metrics, coder: JSON
  serialize :allocation_breakdown, coder: JSON

  enum :status, { pending: 0, active: 1, paused: 2, completed: 3, cancelled: 4 }

  scope :by_channel, ->(channel) { where(channel_type: channel) }
  scope :by_objective, ->(objective) { where(optimization_objective: objective) }
  scope :active_in_period, ->(start_date, end_date) { 
    where(status: :active)
    .where("time_period_start <= ? AND time_period_end >= ?", end_date, start_date) 
  }

  before_save :calculate_allocation_efficiency
  after_update :track_budget_changes, if: :saved_change_to_allocated_amount?

  def allocation_percentage
    return 0 if total_budget.zero?
    (allocated_amount / total_budget * 100).round(2)
  end

  def remaining_budget
    total_budget - allocated_amount
  end

  def is_over_budget?
    allocated_amount > total_budget
  end

  def duration_days
    (time_period_end - time_period_start).to_i
  end

  def daily_allocation
    return 0 if duration_days.zero?
    allocated_amount / duration_days
  end

  def efficiency_score
    score = performance_metrics&.dig('efficiency_score') || 0.0
    score.is_a?(String) ? score.to_f : score
  end

  def predicted_performance
    predictive_model_data&.dig('predicted_performance') || {}
  end

  def real_time_metrics
    {
      spent_to_date: performance_metrics&.dig('spent_to_date') || 0.0,
      remaining_budget: remaining_budget,
      burn_rate: performance_metrics&.dig('burn_rate') || 0.0,
      performance_trend: performance_metrics&.dig('trend') || 'stable'
    }
  end

  private

  def allocation_does_not_exceed_budget
    return unless total_budget.present? && allocated_amount.present?
    
    if allocated_amount > total_budget
      errors.add(:allocated_amount, "cannot exceed total budget of $#{total_budget}")
    end
  end

  def time_period_is_valid
    return unless time_period_start.present? && time_period_end.present?
    
    if time_period_end <= time_period_start
      errors.add(:time_period_end, "must be after start date")
    end
    
    if time_period_start < Date.current
      errors.add(:time_period_start, "cannot be in the past")
    end
  end

  def predictive_model_data_is_valid
    return unless predictive_model_data.is_a?(Hash)
    
    required_fields = %w[model_version confidence_score predicted_performance]
    missing_fields = required_fields - predictive_model_data.keys
    
    if missing_fields.any?
      errors.add(:predictive_model_data, "missing required fields: #{missing_fields.join(', ')}")
    end
    
    confidence = predictive_model_data['confidence_score']
    if confidence.present? && (confidence < 0 || confidence > 1)
      errors.add(:predictive_model_data, "confidence_score must be between 0 and 1")
    end
  end

  def calculate_allocation_efficiency
    return unless allocated_amount.present? && total_budget.present?
    
    if allocated_amount > 0
      base_efficiency = (allocated_amount / total_budget * 100).round(2)
      
      channel_multiplier = case channel_type
      when 'social_media' then 1.0
      when 'search' then 1.2
      when 'email' then 1.1
      when 'display' then 0.9
      when 'video' then 0.95
      when 'content_marketing' then 1.05
      else 1.0
      end
      
      calculated_efficiency = (base_efficiency * channel_multiplier).round(2)
      
      # Store efficiency score in performance_metrics
      self.performance_metrics ||= {}
      self.performance_metrics['efficiency_score'] = calculated_efficiency
    else
      self.performance_metrics ||= {}
      self.performance_metrics['efficiency_score'] = 0.0
    end
  end

  def track_budget_changes
    Rails.logger.info "Budget allocation changed for #{name}: #{allocated_amount_before_last_save} -> #{allocated_amount}"
    
    metrics = performance_metrics || {}
    metrics['allocation_history'] ||= []
    metrics['allocation_history'] << {
      changed_at: Time.current.iso8601,
      old_amount: allocated_amount_before_last_save.to_f,
      new_amount: allocated_amount.to_f,
      change_reason: 'manual_adjustment'
    }
    
    self.performance_metrics = metrics
    update_column(:performance_metrics, metrics) if persisted?
  end
end