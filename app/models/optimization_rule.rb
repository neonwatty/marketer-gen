# frozen_string_literal: true

class OptimizationRule < ApplicationRecord
  belongs_to :campaign_plan
  has_many :optimization_executions, dependent: :destroy

  RULE_TYPES = %w[
    budget_reallocation
    bid_adjustment
    audience_expansion
    audience_refinement
    creative_rotation
    schedule_optimization
    platform_optimization
    content_variant_testing
  ].freeze

  TRIGGER_TYPES = %w[
    performance_threshold
    schedule_based
    cost_efficiency
    conversion_rate
    engagement_rate
    roi_threshold
  ].freeze

  STATUSES = %w[active inactive paused testing].freeze

  validates :campaign_plan_id, presence: true
  validates :rule_type, presence: true, inclusion: { in: RULE_TYPES }
  validates :trigger_type, presence: true, inclusion: { in: TRIGGER_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :name, presence: true, length: { maximum: 255 }
  validates :priority, presence: true, numericality: { 
    greater_than_or_equal_to: 1, 
    less_than_or_equal_to: 10 
  }
  validates :confidence_threshold, presence: true, numericality: { 
    greater_than_or_equal_to: 0.0, 
    less_than_or_equal_to: 1.0 
  }

  serialize :trigger_conditions, coder: JSON
  serialize :optimization_actions, coder: JSON
  serialize :safety_checks, coder: JSON
  serialize :rollback_conditions, coder: JSON
  serialize :metadata, coder: JSON

  scope :active, -> { where(status: 'active') }
  scope :by_priority, -> { order(:priority) }
  scope :by_rule_type, ->(type) { where(rule_type: type) }
  scope :by_trigger_type, ->(type) { where(trigger_type: type) }
  scope :high_confidence, -> { where('confidence_threshold >= ?', 0.8) }
  scope :for_campaign, ->(campaign_id) { where(campaign_plan_id: campaign_id) }

  before_validation :set_default_values, on: :create
  before_validation :validate_json_fields

  def active?
    status == 'active'
  end

  def inactive?
    status == 'inactive'
  end

  def paused?
    status == 'paused'
  end

  def testing?
    status == 'testing'
  end

  def can_be_executed?
    active? && !execution_in_cooldown? && campaign_plan.execution_in_progress?
  end

  def execution_in_cooldown?
    return false unless last_executed_at.present?
    cooldown_period = metadata.dig('cooldown_hours') || 24
    last_executed_at > cooldown_period.hours.ago
  end

  def parsed_trigger_conditions
    return {} unless trigger_conditions.present?
    trigger_conditions.is_a?(String) ? JSON.parse(trigger_conditions) : trigger_conditions
  rescue JSON::ParserError
    {}
  end

  def parsed_optimization_actions
    return {} unless optimization_actions.present?
    optimization_actions.is_a?(String) ? JSON.parse(optimization_actions) : optimization_actions
  rescue JSON::ParserError
    {}
  end

  def parsed_safety_checks
    return {} unless safety_checks.present?
    safety_checks.is_a?(String) ? JSON.parse(safety_checks) : safety_checks
  rescue JSON::ParserError
    {}
  end

  def parsed_rollback_conditions
    return {} unless rollback_conditions.present?
    rollback_conditions.is_a?(String) ? JSON.parse(rollback_conditions) : rollback_conditions
  rescue JSON::ParserError
    {}
  end

  def should_trigger?(performance_data)
    return false unless can_be_executed?
    
    conditions = parsed_trigger_conditions
    return false if conditions.empty?

    case trigger_type
    when 'performance_threshold'
      check_performance_thresholds(performance_data, conditions)
    when 'cost_efficiency'
      check_cost_efficiency(performance_data, conditions)
    when 'conversion_rate'
      check_conversion_rate(performance_data, conditions)
    when 'engagement_rate'
      check_engagement_rate(performance_data, conditions)
    when 'roi_threshold'
      check_roi_threshold(performance_data, conditions)
    when 'schedule_based'
      check_schedule_based(conditions)
    else
      false
    end
  end

  def record_execution!(result)
    transaction do
      optimization_executions.create!(
        executed_at: Time.current,
        result: result,
        performance_data_snapshot: result[:performance_snapshot],
        actions_taken: result[:actions_taken],
        metadata: {
          triggered_by: result[:trigger_reason],
          confidence_score: result[:confidence_score],
          safety_checks_passed: result[:safety_checks_passed]
        }
      )

      update!(
        last_executed_at: Time.current,
        execution_count: execution_count + 1,
        last_execution_result: result[:success] ? 'success' : 'failure'
      )
    end
  end

  def execution_history(limit: 10)
    optimization_executions
      .order(executed_at: :desc)
      .limit(limit)
      .map(&:execution_summary)
  end

  def performance_impact_summary
    executions = optimization_executions.successful.recent.limit(5)
    return {} if executions.empty?

    {
      total_executions: executions.count,
      success_rate: calculate_success_rate,
      average_improvement: calculate_average_improvement(executions),
      best_performance_gain: calculate_best_performance_gain(executions),
      last_execution: executions.first&.execution_summary
    }
  end

  def pause!
    update!(status: 'paused', paused_at: Time.current)
  end

  def resume!
    update!(status: 'active', paused_at: nil)
  end

  def deactivate!
    update!(status: 'inactive', deactivated_at: Time.current)
  end

  def rollback!
    return false unless optimization_executions.recent.any?
    
    transaction do
      recent_executions = optimization_executions.successful.recent.limit(5)
      rollback_success = true
      
      recent_executions.each do |execution|
        unless perform_rollback_action(execution)
          rollback_success = false
          break
        end
      end
      
      if rollback_success
        update!(
          last_rollback_at: Time.current,
          rollback_count: (rollback_count || 0) + 1,
          status: 'paused'
        )
      end
      
      rollback_success
    end
  rescue => e
    Rails.logger.error("Rollback failed for OptimizationRule #{id}: #{e.message}")
    false
  end

  private

  def set_default_values
    self.status ||= 'active'
    self.priority ||= 5
    self.confidence_threshold ||= 0.7
    self.execution_count ||= 0
    self.metadata ||= {}
    self.safety_checks ||= default_safety_checks
  end

  def default_safety_checks
    {
      'max_budget_change_percent' => 20,
      'max_bid_change_percent' => 50,
      'require_minimum_data_points' => 100,
      'minimum_campaign_age_hours' => 24,
      'maximum_daily_executions' => 3
    }
  end

  def validate_json_fields
    validate_json_field(:trigger_conditions, 'Trigger conditions')
    validate_json_field(:optimization_actions, 'Optimization actions')
    validate_json_field(:safety_checks, 'Safety checks')
    validate_json_field(:rollback_conditions, 'Rollback conditions')
    validate_json_field(:metadata, 'Metadata')
  end

  def validate_json_field(field_name, field_display_name)
    field_value = send(field_name)
    return if field_value.blank?

    if field_value.is_a?(String)
      JSON.parse(field_value)
    end
  rescue JSON::ParserError
    errors.add(field_name, "#{field_display_name} must be valid JSON")
  end

  def check_performance_thresholds(performance_data, conditions)
    metric = conditions['metric']
    threshold = conditions['threshold']
    operator = conditions['operator'] || 'less_than'

    return false unless metric && threshold && performance_data[metric]

    current_value = performance_data[metric].to_f

    case operator
    when 'less_than'
      current_value < threshold.to_f
    when 'greater_than'
      current_value > threshold.to_f
    when 'equals'
      current_value == threshold.to_f
    else
      false
    end
  end

  def check_cost_efficiency(performance_data, conditions)
    max_cpc = conditions['max_cpc']
    max_cpm = conditions['max_cpm']

    return false unless performance_data['cost_metrics']

    cost_metrics = performance_data['cost_metrics']
    
    if max_cpc && cost_metrics['cpc']
      return true if cost_metrics['cpc'].to_f > max_cpc.to_f
    end
    
    if max_cpm && cost_metrics['cpm']
      return true if cost_metrics['cpm'].to_f > max_cpm.to_f
    end

    false
  end

  def check_conversion_rate(performance_data, conditions)
    min_conversion_rate = conditions['min_conversion_rate']
    return false unless min_conversion_rate && performance_data['conversion_rate']

    performance_data['conversion_rate'].to_f < min_conversion_rate.to_f
  end

  def check_engagement_rate(performance_data, conditions)
    min_engagement_rate = conditions['min_engagement_rate']
    return false unless min_engagement_rate && performance_data['engagement_rate']

    performance_data['engagement_rate'].to_f < min_engagement_rate.to_f
  end

  def check_roi_threshold(performance_data, conditions)
    min_roi = conditions['min_roi']
    return false unless min_roi && performance_data['roi']

    performance_data['roi'].to_f < min_roi.to_f
  end

  def check_schedule_based(conditions)
    schedule_type = conditions['schedule_type']
    
    case schedule_type
    when 'daily'
      check_daily_schedule(conditions)
    when 'hourly'
      check_hourly_schedule(conditions)
    when 'weekly'
      check_weekly_schedule(conditions)
    else
      false
    end
  end

  def check_daily_schedule(conditions)
    execution_hour = conditions['execution_hour'] || 9
    return false unless (0..23).include?(execution_hour.to_i)

    Time.current.hour == execution_hour.to_i
  end

  def check_hourly_schedule(conditions)
    execution_minute = conditions['execution_minute'] || 0
    return false unless (0..59).include?(execution_minute.to_i)

    Time.current.min == execution_minute.to_i
  end

  def check_weekly_schedule(conditions)
    execution_day = conditions['execution_day'] || 1
    execution_hour = conditions['execution_hour'] || 9
    
    return false unless (0..6).include?(execution_day.to_i)
    return false unless (0..23).include?(execution_hour.to_i)

    Time.current.wday == execution_day.to_i && Time.current.hour == execution_hour.to_i
  end

  def calculate_success_rate
    total = optimization_executions.count
    return 0 if total.zero?

    successful = optimization_executions.successful.count
    (successful.to_f / total * 100).round(2)
  end

  def calculate_average_improvement(executions)
    improvements = executions.map(&:performance_improvement).compact
    return 0 if improvements.empty?

    (improvements.sum.to_f / improvements.length).round(2)
  end

  def calculate_best_performance_gain(executions)
    improvements = executions.map(&:performance_improvement).compact
    improvements.max || 0
  end

  def perform_rollback_action(execution)
    actions_taken = execution.actions_taken || {}
    rollback_conditions = parsed_rollback_conditions
    
    # For now, just log the rollback attempt
    # In a real implementation, this would reverse the actions taken
    Rails.logger.info("Rolling back execution #{execution.id} for rule #{id}")
    
    # Check if rollback conditions are met
    if rollback_conditions.present?
      return check_rollback_conditions(rollback_conditions)
    end
    
    true
  rescue => e
    Rails.logger.error("Failed to rollback execution #{execution.id}: #{e.message}")
    false
  end

  def check_rollback_conditions(conditions)
    # Simple rollback condition checking
    # In a real implementation, this would check specific metrics
    return true unless conditions['require_performance_decline']
    
    recent_performance = optimization_executions.recent.limit(3).map(&:performance_improvement).compact.average
    recent_performance.to_f < 0
  rescue
    true
  end
end