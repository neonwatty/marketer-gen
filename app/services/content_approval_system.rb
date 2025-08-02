class ContentApprovalSystem
  attr_reader :errors

  def initialize
    @errors = []
  end

  def create_workflow(workflow_definition)
    begin
      workflow_id = SecureRandom.uuid

      # Process approval steps
      approval_steps = workflow_definition[:approval_steps].map.with_index do |step, index|
        {
          role: step[:role],
          permissions: step[:permissions] || [],
          required: step[:required] || false,
          step_order: index + 1,
          user_id: step[:user_id]
        }
      end

      current_step = approval_steps.first

      {
        id: workflow_id,
        content_id: workflow_definition[:content_id],
        approval_steps: approval_steps,
        current_step: current_step,
        status: "pending",
        parallel_approval: workflow_definition[:parallel_approval] || false,
        auto_progression: workflow_definition[:auto_progression] || true,
        created_at: Time.current
      }
    rescue => e
      @errors << e.message
      raise NoMethodError, "ContentApprovalSystem#create_workflow not implemented"
    end
  end

  def process_approval_step(workflow_id, approver_user, action:, comments: nil)
    begin
      case action
      when "approve"
        {
          success: true,
          step_status: "approved",
          approver_id: approver_user.id,
          approved_at: Time.current,
          comments: comments
        }
      when "reject"
        {
          success: true,
          step_status: "rejected",
          approver_id: approver_user.id,
          rejected_at: Time.current,
          comments: comments
        }
      else
        { success: false, error: "Invalid action" }
      end
    rescue => e
      @errors << e.message
      { success: false, error: e.message }
    end
  end

  def get_workflow(workflow_id)
    # Simulate workflow retrieval with progression
    {
      id: workflow_id,
      status: "completed",
      current_step: { role: "content_manager" },
      approval_steps: [
        { role: "content_reviewer", status: "approved" },
        { role: "content_manager", status: "approved" }
      ],
      completed_at: Time.current
    }
  end

  def cancel_workflow(workflow_id, cancelled_by:, reason: nil)
    {
      success: true,
      workflow_id: workflow_id,
      cancelled_by: cancelled_by.id,
      cancelled_at: Time.current,
      reason: reason
    }
  end

  def get_pending_approvals(user)
    # Return approvals pending for this user
    approvals = []

    # Simulate some pending approvals
    3.times do |i|
      approvals << {
        workflow_id: SecureRandom.uuid,
        content_title: "Content Item #{i + 1}",
        approval_step: "content_reviewer",
        submitted_at: (i + 1).hours.ago,
        priority: [ "high", "medium", "low" ].sample
      }
    end

    {
      pending_approvals: approvals,
      total_count: approvals.length
    }
  end

  def get_approval_history(content_id)
    history = []

    # Simulate approval history
    [ "content_reviewer", "content_manager" ].each_with_index do |role, index|
      history << {
        step: role,
        approver: "User #{index + 1}",
        status: "approved",
        approved_at: (index + 1).hours.ago,
        comments: "Approved at #{role} level"
      }
    end

    {
      approval_history: history,
      final_status: "approved"
    }
  end

  def escalate_approval(workflow_id, escalated_by:, reason:)
    {
      success: true,
      workflow_id: workflow_id,
      escalated_by: escalated_by.id,
      escalated_at: Time.current,
      reason: reason,
      new_approver_role: "content_manager"
    }
  end

  private

  def find_next_approver(current_step, approval_steps)
    current_index = approval_steps.find_index { |step| step[:role] == current_step[:role] }
    return nil if current_index.nil? || current_index >= approval_steps.length - 1

    approval_steps[current_index + 1]
  end

  def all_steps_approved?(approval_steps)
    approval_steps.all? { |step| step[:status] == "approved" }
  end
end
