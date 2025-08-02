class CampaignApprovalWorkflow
  def initialize(campaign)
    @campaign = campaign
  end

  def create_workflow(approval_steps)
    return { success: false, error: "Approval steps cannot be empty" } if approval_steps.empty?

    workflow_id = SecureRandom.uuid
    workflow_data = {
      id: workflow_id,
      campaign_id: @campaign.id,
      approval_steps: approval_steps.map.with_index do |step, index|
        {
          step_number: index + 1,
          role: step[:role],
          user_id: step[:user_id],
          status: index == 0 ? "pending" : "waiting",
          approved_at: nil,
          rejected_at: nil,
          comments: nil
        }
      end,
      status: "pending",
      current_step: 1,
      current_approver_id: approval_steps.first[:user_id],
      created_at: Time.current,
      updated_at: Time.current
    }

    # In a real implementation, this would be stored in the database
    # For now, we'll store it in a class variable for the test
    @@workflows ||= {}
    @@workflows[workflow_id] = workflow_data

    {
      id: workflow_id,
      approval_steps: workflow_data[:approval_steps],
      status: workflow_data[:status],
      current_approver_id: workflow_data[:current_approver_id]
    }
  end

  def approve_step(workflow_id, approver_user, comments = nil)
    workflow = get_workflow_data(workflow_id)
    return { success: false, error: "Workflow not found" } unless workflow

    current_step = workflow[:approval_steps].find { |step| step[:step_number] == workflow[:current_step] }
    return { success: false, error: "Current step not found" } unless current_step

    # Verify the approver is authorized for this step
    unless current_step[:user_id] == approver_user.id
      return { success: false, error: "User not authorized to approve this step" }
    end

    # Update the current step
    current_step[:status] = "approved"
    current_step[:approved_at] = Time.current
    current_step[:comments] = comments

    # Move to next step or complete workflow
    next_step_number = workflow[:current_step] + 1
    next_step = workflow[:approval_steps].find { |step| step[:step_number] == next_step_number }

    if next_step
      # Move to next step
      next_step[:status] = "pending"
      workflow[:current_step] = next_step_number
      workflow[:current_approver_id] = next_step[:user_id]
      workflow[:status] = "pending"
    else
      # Complete workflow
      workflow[:status] = "approved"
      workflow[:current_approver_id] = nil
      workflow[:completed_at] = Time.current
    end

    workflow[:updated_at] = Time.current
    save_workflow(workflow_id, workflow)

    { success: true, status: workflow[:status], next_approver_id: workflow[:current_approver_id] }
  end

  def reject_step(workflow_id, approver_user, rejection_reason)
    workflow = get_workflow_data(workflow_id)
    return { success: false, error: "Workflow not found" } unless workflow

    current_step = workflow[:approval_steps].find { |step| step[:step_number] == workflow[:current_step] }
    return { success: false, error: "Current step not found" } unless current_step

    # Verify the approver is authorized for this step
    unless current_step[:user_id] == approver_user.id
      return { success: false, error: "User not authorized to reject this step" }
    end

    # Update the current step and workflow
    current_step[:status] = "rejected"
    current_step[:rejected_at] = Time.current
    current_step[:comments] = rejection_reason

    workflow[:status] = "rejected"
    workflow[:rejection_reason] = rejection_reason
    workflow[:rejected_at] = Time.current
    workflow[:updated_at] = Time.current

    save_workflow(workflow_id, workflow)

    { success: true, status: "rejected", rejection_reason: rejection_reason }
  end

  def get_workflow(workflow_id)
    workflow = get_workflow_data(workflow_id)
    return nil unless workflow

    {
      id: workflow[:id],
      campaign_id: workflow[:campaign_id],
      status: workflow[:status],
      current_step: workflow[:current_step],
      current_approver_id: workflow[:current_approver_id],
      approval_steps: workflow[:approval_steps],
      created_at: workflow[:created_at],
      updated_at: workflow[:updated_at],
      completed_at: workflow[:completed_at],
      rejected_at: workflow[:rejected_at],
      rejection_reason: workflow[:rejection_reason]
    }
  end

  def get_pending_workflows_for_user(user)
    @@workflows&.values&.select do |workflow|
      workflow[:current_approver_id] == user.id && workflow[:status] == "pending"
    end || []
  end

  def get_workflow_history(workflow_id)
    workflow = get_workflow_data(workflow_id)
    return [] unless workflow

    workflow[:approval_steps].map do |step|
      {
        step_number: step[:step_number],
        role: step[:role],
        user_id: step[:user_id],
        status: step[:status],
        approved_at: step[:approved_at],
        rejected_at: step[:rejected_at],
        comments: step[:comments]
      }
    end
  end

  def restart_workflow(workflow_id)
    workflow = get_workflow_data(workflow_id)
    return { success: false, error: "Workflow not found" } unless workflow

    # Reset all steps
    workflow[:approval_steps].each_with_index do |step, index|
      step[:status] = index == 0 ? "pending" : "waiting"
      step[:approved_at] = nil
      step[:rejected_at] = nil
      step[:comments] = nil
    end

    # Reset workflow status
    workflow[:status] = "pending"
    workflow[:current_step] = 1
    workflow[:current_approver_id] = workflow[:approval_steps].first[:user_id]
    workflow[:completed_at] = nil
    workflow[:rejected_at] = nil
    workflow[:rejection_reason] = nil
    workflow[:updated_at] = Time.current

    save_workflow(workflow_id, workflow)

    { success: true, message: "Workflow restarted successfully" }
  end

  private

  def get_workflow_data(workflow_id)
    @@workflows ||= {}
    @@workflows[workflow_id]
  end

  def save_workflow(workflow_id, workflow_data)
    @@workflows ||= {}
    @@workflows[workflow_id] = workflow_data
  end

  # Class method to access workflows for testing
  def self.workflows
    @@workflows ||= {}
  end

  # Class method to reset workflows for testing
  def self.reset_workflows!
    @@workflows = {}
  end
end
