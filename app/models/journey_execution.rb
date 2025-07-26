class JourneyExecution < ApplicationRecord
  include AASM
  
  belongs_to :journey
  belongs_to :user
  belongs_to :current_step, class_name: 'JourneyStep', optional: true
  has_many :step_executions, dependent: :destroy
  
  validates :user_id, uniqueness: { scope: :journey_id, message: "can only have one execution per journey" }
  
  scope :active, -> { where(status: %w[initialized running paused]) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  
  aasm column: :status do
    state :initialized, initial: true
    state :running
    state :paused
    state :completed
    state :failed
    state :cancelled
    
    event :start do
      transitions from: [:initialized, :paused], to: :running do
        guard { journey.published? }
        after { record_start_time }
      end
    end
    
    event :pause do
      transitions from: :running, to: :paused do
        after { record_pause_time }
      end
    end
    
    event :resume do
      transitions from: :paused, to: :running do
        after { clear_pause_time }
      end
    end
    
    event :complete do
      transitions from: [:running, :paused], to: :completed do
        after { record_completion_time }
      end
    end
    
    event :fail do
      transitions from: [:initialized, :running, :paused], to: :failed do
        after { record_failure }
      end
    end
    
    event :cancel do
      transitions from: [:initialized, :running, :paused], to: :cancelled
    end
    
    event :reset do
      transitions from: [:completed, :failed, :cancelled], to: :initialized do
        after { reset_execution_state }
      end
    end
  end
  
  def next_step
    return journey.journey_steps.entry_points.first if current_step.nil?
    
    # Find next step based on transitions and conditions
    available_transitions = current_step.transitions_from.includes(:to_step)
    
    available_transitions.each do |transition|
      if transition.evaluate(execution_context)
        return transition.to_step
      end
    end
    
    # If no conditional transitions match, return sequential next step
    journey.journey_steps.where(position: current_step.position + 1).first
  end
  
  def advance_to_next_step!
    next_step_obj = next_step
    
    if next_step_obj
      update!(current_step: next_step_obj)
      create_step_execution(next_step_obj)
      
      # Check if this is an exit point
      complete! if next_step_obj.is_exit_point?
    else
      # No more steps available
      complete!
    end
  end
  
  def can_advance?
    return false unless running?
    return false if current_step&.is_exit_point?
    
    next_step.present?
  end
  
  def progress_percentage
    return 0 if journey.total_steps == 0
    return 100 if completed?
    
    current_position = current_step&.position || 0
    ((current_position.to_f / journey.total_steps) * 100).round(1)
  end
  
  def elapsed_time
    return 0 unless started_at
    
    end_time = completed_at || paused_at || Time.current
    end_time - started_at
  end
  
  def add_context(key, value)
    context = execution_context.dup
    context[key.to_s] = value
    update!(execution_context: context)
  end
  
  def get_context(key)
    execution_context[key.to_s]
  end
  
  private
  
  def record_start_time
    update!(started_at: Time.current) if started_at.nil?
  end
  
  def record_pause_time
    update!(paused_at: Time.current)
  end
  
  def clear_pause_time
    update!(paused_at: nil)
  end
  
  def record_completion_time
    update!(completed_at: Time.current, paused_at: nil)
  end
  
  def record_failure
    add_context('failure_time', Time.current)
    add_context('failure_step', current_step&.name)
  end
  
  def reset_execution_state
    update!(
      current_step: nil,
      started_at: nil,
      completed_at: nil,
      paused_at: nil,
      execution_context: {},
      completion_notes: nil
    )
    step_executions.destroy_all
  end
  
  def create_step_execution(step)
    step_executions.create!(
      journey_step: step,
      started_at: Time.current,
      context: execution_context.dup
    )
  end
end
