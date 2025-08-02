class ContentWorkflow < ApplicationRecord
  belongs_to :content_repository
  belongs_to :created_by, class_name: "User"
  has_many :content_approvals, dependent: :destroy

  validates :name, presence: true
  validates :status, presence: true

  enum status: {
    pending: 0,
    in_progress: 1,
    completed: 2,
    cancelled: 3,
    rejected: 4
  }

  scope :active, -> { where(status: [ "pending", "in_progress" ]) }
  scope :completed, -> { where(status: [ "completed", "rejected", "cancelled" ]) }
  scope :by_repository, ->(repo_id) { where(content_repository_id: repo_id) }

  after_create :initialize_approval_steps
  before_update :check_completion_status

  def self.create_default_workflow(content_repository:, creator:)
    create!(
      content_repository: content_repository,
      created_by: creator,
      name: "Standard Content Approval",
      parallel_approval: false,
      auto_progression: true,
      step_timeout_hours: 72
    )
  end

  def current_step
    content_approvals.pending.order(:step_order).first
  end

  def progress_percentage
    return 0 if content_approvals.empty?

    completed_steps = content_approvals.where(status: [ "approved", "rejected" ]).count
    total_steps = content_approvals.count

    (completed_steps.to_f / total_steps * 100).round(2)
  end

  def can_be_cancelled?
    %w[pending in_progress].include?(status)
  end

  def cancel!(reason: nil, cancelled_by:)
    return false unless can_be_cancelled?

    transaction do
      update!(
        status: "cancelled",
        cancellation_reason: reason,
        cancelled_by: cancelled_by,
        cancelled_at: Time.current
      )

      # Cancel all pending approvals
      content_approvals.pending.update_all(status: "cancelled")
    end

    true
  end

  def restart!(restarted_by:)
    return false unless %w[cancelled rejected].include?(status)

    transaction do
      update!(
        status: "pending",
        cancelled_by: nil,
        cancelled_at: nil,
        cancellation_reason: nil,
        restarted_by: restarted_by,
        restarted_at: Time.current
      )

      # Reset all approval steps to pending
      content_approvals.update_all(
        status: "pending",
        approved_at: nil,
        rejected_at: nil,
        approver_comments: nil
      )

      # Start with first step
      content_approvals.order(:step_order).first&.update!(status: "pending")
    end

    true
  end

  def approval_history
    content_approvals.completed_approvals
                    .includes(:assigned_approver)
                    .order(:step_order)
                    .map do |approval|
      {
        step: approval.approval_step,
        approver: approval.assigned_approver&.full_name,
        status: approval.status,
        comments: approval.approver_comments,
        timestamp: approval.approved_at || approval.rejected_at,
        duration: approval_duration(approval)
      }
    end
  end

  def estimated_completion_time
    return nil if completed?

    remaining_steps = content_approvals.pending.count
    remaining_steps * step_timeout_hours.hours
  end

  def is_overdue?
    return false if completed?

    current_step&.overdue? || false
  end

  def next_approvers
    if parallel_approval?
      content_approvals.pending.includes(:assigned_approver).map(&:assigned_approver).compact
    else
      [ current_step&.assigned_approver ].compact
    end
  end

  private

  def initialize_approval_steps
    # This will be called after workflow creation
    # The approval steps should be created separately based on workflow definition
  end

  def check_completion_status
    return unless status_changed?

    if all_approvals_completed?
      self.status = all_approvals_approved? ? "completed" : "rejected"
      self.completed_at = Time.current
    elsif any_approval_in_progress?
      self.status = "in_progress"
    end
  end

  def all_approvals_completed?
    content_approvals.all? { |approval| %w[approved rejected cancelled].include?(approval.status) }
  end

  def all_approvals_approved?
    content_approvals.all? { |approval| approval.status == "approved" }
  end

  def any_approval_in_progress?
    content_approvals.any? { |approval| approval.status == "in_review" }
  end

  def approval_duration(approval)
    start_time = approval.created_at
    end_time = approval.approved_at || approval.rejected_at

    return nil unless end_time

    ((end_time - start_time) / 1.hour).round(2)
  end
end
