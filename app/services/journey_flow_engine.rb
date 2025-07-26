class JourneyFlowEngine
    attr_reader :execution, :journey, :user
    
    def initialize(execution)
      @execution = execution
      @journey = execution.journey
      @user = execution.user
    end
    
    def self.start_journey(journey, user, context = {})
      execution = find_or_create_execution(journey, user)
      engine = new(execution)
      engine.start!(context)
    end
    
    def self.find_or_create_execution(journey, user)
      JourneyExecution.find_or_create_by(journey: journey, user: user) do |exec|
        exec.execution_context = {}
      end
    end
    
    def start!(initial_context = {})
      return execution if execution.running? || execution.completed?
      
      # Add initial context
      initial_context.each { |key, value| execution.add_context(key, value) }
      
      # Find entry point
      entry_step = find_entry_step
      unless entry_step
        execution.fail!
        raise "No entry step found for journey #{journey.name}"
      end
      
      execution.update!(current_step: entry_step)
      execution.start!
      
      # Create first step execution
      step_execution = execution.step_executions.create!(
        journey_step: entry_step,
        started_at: Time.current,
        context: execution.execution_context.dup
      )
      
      execution
    end
    
    def advance!
      return false unless execution.can_advance?
      
      current_step_execution = execution.step_executions
        .where(journey_step: execution.current_step)
        .last
      
      # Complete current step if not already completed
      if current_step_execution&.pending?
        current_step_execution.complete!
      end
      
      # Find next step based on conditions
      next_step = evaluate_next_step
      
      if next_step
        execution.update!(current_step: next_step)
        
        # Create new step execution
        execution.step_executions.create!(
          journey_step: next_step,
          started_at: Time.current,
          context: execution.execution_context.dup
        )
        
        # Check if this is an exit point
        if next_step.is_exit_point?
          execution.complete!
        end
        
        true
      else
        # No more steps - complete the journey
        execution.complete!
        false
      end
    end
    
    def pause!
      execution.pause! if execution.may_pause?
    end
    
    def resume!
      execution.resume! if execution.may_resume?
    end
    
    def fail!(reason = nil)
      execution.add_context('failure_reason', reason) if reason
      execution.fail! if execution.may_fail?
    end
    
    def evaluate_conditions(step, context = nil)
      context ||= execution.execution_context
      step.evaluate_conditions(context)
    end
    
    def get_available_next_steps
      return [] unless execution.current_step
      
      current_step = execution.current_step
      available_steps = []
      
      # Check conditional transitions first (ordered by priority)
      current_step.transitions_from.includes(:to_step).order(:priority).each do |transition|
        if transition.evaluate(execution.execution_context)
          available_steps << {
            step: transition.to_step,
            transition_type: transition.transition_type,
            conditions_met: true
          }
          break # Return only the first (highest priority) matching transition
        end
      end
      
      # If no conditional transitions, check sequential next step
      if available_steps.empty?
        next_sequential = journey.journey_steps
          .where('position > ?', current_step.position)
          .order(:position)
          .first
        
        if next_sequential
          available_steps << {
            step: next_sequential,
            transition_type: 'sequential',
            conditions_met: true
          }
        end
      end
      
      available_steps
    end
    
    def simulate_journey(context = {})
      simulation_context = execution.execution_context.merge(context)
      current_step = execution.current_step || find_entry_step
      visited_steps = []
      max_steps = 50 # Prevent infinite loops
      
      while current_step && visited_steps.length < max_steps
        visited_steps << {
          step: current_step,
          stage: current_step.stage,
          conditions: current_step.conditions
        }
        
        # Find next step based on simulation context
        next_step = nil
        current_step.transitions_from.each do |transition|
          if transition.evaluate(simulation_context)
            next_step = transition.to_step
            break
          end
        end
        
        # Break if we hit an exit point
        break if current_step.is_exit_point?
        
        # If no conditional transition, try sequential
        next_step ||= journey.journey_steps
          .where('position > ?', current_step.position)
          .order(:position)
          .first
        
        current_step = next_step
      end
      
      visited_steps
    end
    
    private
    
    def find_entry_step
      # First try explicit entry points
      entry_step = journey.journey_steps.entry_points.first
      
      # Fall back to first step by position
      entry_step ||= journey.journey_steps.order(:position).first
      
      entry_step
    end
    
    def evaluate_next_step
      current_step = execution.current_step
      return nil unless current_step
      
      # Check conditional transitions first (ordered by priority)
      current_step.transitions_from.includes(:to_step).order(:priority).each do |transition|
        if transition.evaluate(execution.execution_context)
          return transition.to_step
        end
      end
      
      # Fall back to sequential next step
      journey.journey_steps
        .where('position > ?', current_step.position)
        .order(:position)
        .first
    end
end