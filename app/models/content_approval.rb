class ContentApproval < ApplicationRecord
  belongs_to :content_repository
  belongs_to :workflow, class_name: "ContentWorkflow", optional: true
  belongs_to :user
  belongs_to :assigned_approver, class_name: "User", optional: true

  validates :approval_step, presence: true
  validates :status, presence: true

  enum status: {
    pending: 0,
    approved: 1,
    rejected: 2,
    cancelled: 3,
    in_review: 4
  }

  enum approval_step: {
    content_creator: 0,
    content_reviewer: 1,
    content_manager: 2,
    brand_guardian: 3,
    legal_review: 4,
    final_approval: 5
  }

  scope :by_status, ->(status) { where(status: status) }
  scope :by_step, ->(step) { where(approval_step: step) }
  scope :by_approver, ->(user_id) { where(assigned_approver_id: user_id) }
  scope :by_repository, ->(repo_id) { where(content_repository_id: repo_id) }
  scope :pending_approvals, -> { where(status: "pending") }
  scope :completed_approvals, -> { where(status: [ "approved", "rejected" ]) }

  before_save :set_approval_timestamp
  after_update :notify_next_approver, if: :status_changed_to_approved?
  after_update :handle_rejection, if: :status_changed_to_rejected?

  def self.create_workflow_approvals(content_repository:, workflow_steps:)
    transaction do
      workflow_steps.each_with_index do |step, index|
        create!(
          content_repository: content_repository,
          approval_step: step[:role],
          assigned_approver: step[:user_id] ? User.find(step[:user_id]) : nil,
          status: index == 0 ? "pending" : "pending",
          step_order: index + 1,
          user: content_repository.user
        )
      end
    end
  end

  def can_approve?(current_user)
    return false unless pending?
    return false if assigned_approver && assigned_approver != current_user

    # Check if user has the required role/permissions for this approval step
    case approval_step
    when "content_creator"
      current_user.has_role?(:content_creator) || current_user == content_repository.user
    when "content_reviewer"
      current_user.has_role?(:content_reviewer)
    when "content_manager"
      current_user.has_role?(:content_manager)
    when "brand_guardian"
      current_user.has_role?(:brand_guardian)
    when "legal_review"
      current_user.has_role?(:legal_reviewer)
    when "final_approval"
      current_user.has_role?(:admin) || current_user.has_role?(:content_manager)
    else
      false
    end
  end

  def approve!(approver:, comments: nil)
    return false unless can_approve?(approver)

    update!(
      status: "approved",
      approved_at: Time.current,
      approver_comments: comments,
      assigned_approver: approver
    )

    true
  end

  def reject!(approver:, comments:)
    return false unless can_approve?(approver)

    update!(
      status: "rejected",
      rejected_at: Time.current,
      approver_comments: comments,
      assigned_approver: approver
    )

    true
  end

  def next_approval_step
    workflow&.content_approvals&.where("step_order > ?", step_order)&.order(:step_order)&.first
  end

  def previous_approval_step
    workflow&.content_approvals&.where("step_order < ?", step_order)&.order(:step_order)&.last
  end

  def approval_deadline
    created_at + (workflow&.step_timeout_hours || 72).hours
  end

  def overdue?
    Time.current > approval_deadline && pending?
  end

  private

  def set_approval_timestamp
    case status
    when "approved"
      self.approved_at = Time.current if approved_at.nil?
    when "rejected"
      self.rejected_at = Time.current if rejected_at.nil?
    when "in_review"
      self.reviewed_at = Time.current if reviewed_at.nil?
    end
  end

  def status_changed_to_approved?
    saved_change_to_status? && status == "approved"
  end

  def status_changed_to_rejected?
    saved_change_to_status? && status == "rejected"
  end

  def notify_next_approver
    next_step = next_approval_step
    return unless next_step

    next_step.update!(status: "pending")
    # Trigger notification job
    ContentApprovalNotificationJob.perform_later(next_step.id)
  end

  def handle_rejection
    # Mark all subsequent approval steps as cancelled
    workflow&.content_approvals&.where("step_order > ?", step_order)&.update_all(status: "cancelled")

    # Update content repository status
    content_repository.update!(status: "rejected")

    # Trigger rejection notification
    ContentRejectionNotificationJob.perform_later(id)
  end
end
