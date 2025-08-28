# frozen_string_literal: true

class OptimizationExecution < ApplicationRecord
  belongs_to :optimization_rule

  STATUSES = %w[successful failed partial_success rolled_back].freeze

  validates :optimization_rule_id, presence: true
  validates :executed_at, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  serialize :result, coder: JSON
  serialize :performance_data_snapshot, coder: JSON
  serialize :actions_taken, coder: JSON
  serialize :metadata, coder: JSON

  scope :successful, -> { where(status: 'successful') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { where('executed_at >= ?', 30.days.ago) }
  scope :by_rule, ->(rule_id) { where(optimization_rule_id: rule_id) }

  before_validation :set_status_from_result, on: :create

  def successful?
    status == 'successful'
  end

  def failed?
    status == 'failed'
  end

  def rolled_back?
    status == 'rolled_back'
  end

  def execution_summary
    {
      id: id,
      executed_at: executed_at,
      status: status,
      rule_type: optimization_rule.rule_type,
      actions_count: parsed_actions_taken.length,
      performance_improvement: performance_improvement,
      confidence_score: metadata&.dig('confidence_score') || 0
    }
  end

  def performance_improvement
    return 0 unless successful? && performance_data_snapshot.present?

    # Calculate improvement based on before/after metrics
    before_metrics = performance_data_snapshot.dig('before') || {}
    after_metrics = performance_data_snapshot.dig('after') || {}

    primary_metric = optimization_rule.parsed_trigger_conditions.dig('metric') || 'roi'
    
    before_value = before_metrics[primary_metric].to_f
    after_value = after_metrics[primary_metric].to_f

    return 0 if before_value.zero?

    ((after_value - before_value) / before_value * 100).round(2)
  end

  def parsed_actions_taken
    return [] unless actions_taken.present?
    actions_taken.is_a?(String) ? JSON.parse(actions_taken) : actions_taken
  rescue JSON::ParserError
    []
  end

  def rollback!
    return false if rolled_back?

    transaction do
      # Logic to reverse the optimization actions would go here
      # This would integrate with platform APIs to undo changes

      update!(
        status: 'rolled_back',
        rolled_back_at: Time.current,
        metadata: (metadata || {}).merge(
          rolled_back_reason: 'manual_rollback',
          rolled_back_by: Current.user&.id
        )
      )
    end

    true
  end

  private

  def set_status_from_result
    return unless result.present?

    parsed_result = result.is_a?(String) ? JSON.parse(result) : result
    
    self.status = if parsed_result[:success] || parsed_result['success']
                    'successful'
                  elsif parsed_result[:partial] || parsed_result['partial']
                    'partial_success'
                  else
                    'failed'
                  end
  rescue JSON::ParserError
    self.status = 'failed'
  end
end