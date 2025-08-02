class ContentRevision < ApplicationRecord
  belongs_to :content_repository
  belongs_to :revised_by, class_name: "User"

  validates :revision_reason, presence: true

  enum revision_type: {
    minor_edit: 0,
    major_rewrite: 1,
    content_update: 2,
    formatting_change: 3,
    correction: 4,
    compliance_fix: 5,
    brand_alignment: 6
  }

  enum status: {
    draft: 0,
    pending_review: 1,
    approved: 2,
    rejected: 3,
    merged: 4
  }

  scope :by_repository, ->(repo_id) { where(content_repository_id: repo_id) }
  scope :by_user, ->(user_id) { where(revised_by_id: user_id) }
  scope :by_type, ->(type) { where(revision_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "pending_review") }

  before_create :set_revision_number
  after_create :notify_reviewers

  def self.create_revision(content_repository:, revised_by:, changes:, reason:, type: "content_update")
    create!(
      content_repository: content_repository,
      revised_by: revised_by,
      content_before: content_repository.body,
      content_after: changes[:new_content],
      revision_reason: reason,
      revision_type: type,
      changes_summary: changes[:summary],
      status: "pending_review"
    )
  end

  def apply_revision!
    return false unless can_be_applied?

    transaction do
      # Create a new version with the revised content
      content_repository.create_version!(
        body: content_after,
        author: revised_by,
        commit_message: "Applied revision: #{revision_reason}"
      )

      # Update the repository content
      content_repository.update!(
        body: content_after,
        updated_at: Time.current
      )

      # Mark revision as merged
      update!(
        status: "merged",
        applied_at: Time.current
      )
    end

    true
  end

  def can_be_applied?
    approved? && !merged?
  end

  def approve!(approved_by:, comments: nil)
    update!(
      status: "approved",
      approved_by: approved_by,
      approved_at: Time.current,
      approval_comments: comments
    )
  end

  def reject!(rejected_by:, comments:)
    update!(
      status: "rejected",
      rejected_by: rejected_by,
      rejected_at: Time.current,
      rejection_comments: comments
    )
  end

  def diff_summary
    return {} unless content_before.present? && content_after.present?

    before_lines = content_before.split("\n")
    after_lines = content_after.split("\n")

    {
      lines_added: (after_lines - before_lines).count,
      lines_removed: (before_lines - after_lines).count,
      total_changes: calculate_total_changes(before_lines, after_lines),
      change_percentage: calculate_change_percentage
    }
  end

  def preview_changes
    {
      revision_id: id,
      author: revised_by.full_name,
      reason: revision_reason,
      type: revision_type,
      status: status,
      diff: diff_summary,
      content_preview: {
        before: content_before&.truncate(500),
        after: content_after&.truncate(500)
      },
      created_at: created_at
    }
  end

  def rollback_to_previous!
    return false unless merged?

    previous_version = content_repository.content_versions
                                        .where("created_at < ?", applied_at)
                                        .order(:created_at)
                                        .last

    return false unless previous_version

    content_repository.update!(
      body: previous_version.body,
      updated_at: Time.current
    )

    # Create rollback record
    self.class.create!(
      content_repository: content_repository,
      revised_by: Current.user,
      content_before: content_after,
      content_after: previous_version.body,
      revision_reason: "Rollback from revision #{revision_number}",
      revision_type: "correction",
      status: "merged",
      applied_at: Time.current
    )

    true
  end

  private

  def set_revision_number
    last_revision = content_repository.content_revisions.maximum(:revision_number) || 0
    self.revision_number = last_revision + 1
  end

  def notify_reviewers
    # This would trigger a background job to notify relevant reviewers
    ContentRevisionNotificationJob.perform_later(id) if Rails.env.production?
  end

  def calculate_total_changes(before_lines, after_lines)
    max_lines = [ before_lines.length, after_lines.length ].max
    changes = 0

    (0...max_lines).each do |i|
      if before_lines[i] != after_lines[i]
        changes += 1
      end
    end

    changes
  end

  def calculate_change_percentage
    return 0 unless content_before.present? && content_after.present?

    before_length = content_before.length
    after_length = content_after.length

    return 100 if before_length == 0

    change_ratio = (before_length - after_length).abs.to_f / before_length
    (change_ratio * 100).round(2)
  end
end
