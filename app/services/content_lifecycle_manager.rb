class ContentLifecycleManager
  attr_reader :content_id, :errors

  def initialize(content_id)
    @content_id = content_id
    @errors = []
    @current_state = "draft"
    @lifecycle_history = [
      { state: "draft", transitioned_at: Time.current, user_id: nil }
    ]
  end

  def get_current_state
    @current_state
  end

  def transition_to(new_state, user)
    # Validate state transition
    unless valid_transition?(@current_state, new_state)
      return {
        success: false,
        error: "Invalid state transition from #{@current_state} to #{new_state}"
      }
    end

    # Perform the transition
    old_state = @current_state
    @current_state = new_state

    # Record in history
    @lifecycle_history << {
      state: new_state,
      previous_state: old_state,
      transitioned_at: Time.current,
      user_id: user.id,
      user_name: user.full_name || user.email_address
    }

    {
      success: true,
      old_state: old_state,
      new_state: new_state,
      transitioned_by: user.id,
      transitioned_at: Time.current
    }
  rescue => e
    @errors << e.message
    {
      success: false,
      error: e.message
    }
  end

  def get_lifecycle_history
    @lifecycle_history
  end

  def schedule_auto_archive(archive_date:, reason:)
    begin
      job_id = SecureRandom.uuid

      # In production, this would schedule a background job
      scheduled_task = {
        task_type: "auto_archive",
        content_id: content_id,
        scheduled_for: archive_date,
        reason: reason,
        job_id: job_id,
        created_at: Time.current
      }

      @scheduled_tasks ||= []
      @scheduled_tasks << scheduled_task

      {
        success: true,
        scheduled_job_id: job_id,
        archive_date: archive_date,
        reason: reason
      }
    rescue => e
      @errors << e.message
      { success: false, error: e.message }
    end
  end

  def get_scheduled_tasks
    @scheduled_tasks || []
  end

  def cancel_scheduled_task(job_id)
    @scheduled_tasks&.reject! { |task| task[:job_id] == job_id }

    {
      success: true,
      cancelled_job_id: job_id,
      cancelled_at: Time.current
    }
  end

  def can_transition_to?(target_state)
    valid_transition?(@current_state, target_state)
  end

  def get_available_transitions
    case @current_state
    when "draft"
      [ "review", "cancelled" ]
    when "review"
      [ "approved", "rejected", "draft" ]
    when "approved"
      [ "published", "review" ]
    when "published"
      [ "archived", "review" ]
    when "rejected"
      [ "draft", "cancelled" ]
    when "archived"
      [ "published" ] # Can restore from archive
    when "cancelled"
      [ "draft" ]
    else
      []
    end
  end

  def get_state_metadata
    {
      current_state: @current_state,
      state_duration: calculate_state_duration,
      total_transitions: @lifecycle_history.length - 1,
      last_transition: @lifecycle_history.last,
      available_transitions: get_available_transitions
    }
  end

  private

  def valid_transition?(from_state, to_state)
    allowed_transitions = {
      "draft" => [ "review", "cancelled" ],
      "review" => [ "approved", "rejected", "draft", "published" ],
      "approved" => [ "published", "review" ],
      "published" => [ "archived", "review" ],
      "rejected" => [ "draft", "cancelled" ],
      "archived" => [ "published" ],
      "cancelled" => [ "draft" ]
    }

    allowed_transitions[from_state]&.include?(to_state)
  end

  def calculate_state_duration
    last_transition = @lifecycle_history.last
    return 0 unless last_transition

    Time.current - last_transition[:transitioned_at]
  end
end
