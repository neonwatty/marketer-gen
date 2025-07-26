class StepTransition < ApplicationRecord
  belongs_to :from_step, class_name: 'JourneyStep'
  belongs_to :to_step, class_name: 'JourneyStep'
  
  TRANSITION_TYPES = %w[sequential conditional split merge].freeze
  
  validates :from_step, presence: true
  validates :to_step, presence: true
  validates :transition_type, inclusion: { in: TRANSITION_TYPES }
  validates :priority, numericality: { greater_than_or_equal_to: 0 }
  validate :prevent_self_reference
  validate :steps_in_same_journey
  
  scope :by_priority, -> { order(:priority) }
  scope :conditional, -> { where(transition_type: 'conditional') }
  scope :sequential, -> { where(transition_type: 'sequential') }
  
  def evaluate(context = {})
    return true if conditions.blank?
    
    conditions.all? do |condition_type, condition_value|
      evaluate_condition(condition_type, condition_value, context)
    end
  end
  
  def journey
    from_step.journey
  end
  
  private
  
  def prevent_self_reference
    errors.add(:to_step, "can't be the same as from_step") if from_step_id == to_step_id
  end
  
  def steps_in_same_journey
    return unless from_step && to_step
    
    if from_step.journey_id != to_step.journey_id
      errors.add(:base, "Steps must belong to the same journey")
    end
  end
  
  def evaluate_condition(condition_type, condition_value, context)
    case condition_type
    when 'engagement_threshold'
      context[:engagement_score].to_f >= condition_value.to_f
    when 'action_completed'
      Array(context[:completed_actions]).include?(condition_value)
    when 'time_elapsed'
      context[:time_elapsed].to_i >= condition_value.to_i
    when 'form_submitted'
      context[:submitted_forms]&.include?(condition_value)
    when 'link_clicked'
      context[:clicked_links]&.include?(condition_value)
    when 'purchase_made'
      context[:purchases]&.any? { |p| p[:product_id] == condition_value }
    when 'score_range'
      score = context[:score].to_f
      score >= condition_value['min'].to_f && score <= condition_value['max'].to_f
    else
      true
    end
  end
end
