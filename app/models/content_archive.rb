class ContentArchive < ApplicationRecord
  belongs_to :content_repository
  belongs_to :archived_by, class_name: "User"
  belongs_to :restored_by, class_name: "User", optional: true

  validates :archive_reason, presence: true
  validates :retention_period, presence: true
  validates :archive_level, presence: true

  enum archive_level: {
    hot_storage: 0,      # Frequently accessed, quick retrieval
    warm_storage: 1,     # Occasionally accessed, moderate retrieval time
    cold_storage: 2,     # Rarely accessed, slower retrieval
    deep_archive: 3      # Long-term storage, slowest retrieval
  }

  enum status: {
    archiving: 0,        # In process of being archived
    archived: 1,         # Successfully archived
    restoring: 2,        # In process of being restored
    restored: 3,         # Successfully restored
    failed: 4           # Archive/restore operation failed
  }

  scope :by_repository, ->(repo_id) { where(content_repository_id: repo_id) }
  scope :by_level, ->(level) { where(archive_level: level) }
  scope :by_status, ->(status) { where(status: status) }
  scope :active_archives, -> { where(status: "archived") }
  scope :expired, -> { where("retention_expires_at < ?", Time.current) }

  before_create :set_retention_expiry
  before_create :set_storage_location
  after_create :schedule_archival_job

  def self.archive_content(content_repository:, reason:, level: "cold_storage", retention: "7_years", archived_by:)
    archive = create!(
      content_repository: content_repository,
      archive_reason: reason,
      archive_level: level,
      retention_period: retention,
      archived_by: archived_by,
      metadata_preservation: true,
      status: "archiving"
    )

    # Backup metadata before archiving
    archive.backup_metadata!

    archive
  end

  def backup_metadata!
    metadata = {
      repository_data: content_repository.attributes.except("body"),
      versions: content_repository.content_versions.map(&:attributes),
      tags: content_repository.content_tags.map(&:attributes),
      approvals: content_repository.content_approvals.includes(:assigned_approver).map do |approval|
        approval.attributes.merge(approver_name: approval.assigned_approver&.full_name)
      end,
      permissions: content_repository.content_permissions.includes(:user).map do |permission|
        permission.attributes.merge(user_name: permission.user.full_name)
      end,
      revisions: content_repository.content_revisions.map(&:attributes)
    }

    update!(
      metadata_backup: metadata,
      metadata_backup_location: "#{storage_location}/metadata.json"
    )
  end

  def restore!(requested_by:, reason:)
    return false unless can_be_restored?

    transaction do
      update!(
        status: "restoring",
        restore_requested_at: Time.current,
        restore_reason: reason,
        restored_by: requested_by
      )

      # Restore content body
      content_repository.update!(
        body: archived_content_body,
        status: "draft"  # Set to draft for review after restoration
      )

      # Mark as restored
      update!(
        status: "restored",
        restored_at: Time.current
      )
    end

    # Schedule background job to notify about restoration
    ContentRestorationNotificationJob.perform_later(id)

    true
  end

  def can_be_restored?
    archived? && !expired?
  end

  def expired?
    retention_expires_at.present? && retention_expires_at < Time.current
  end

  def retrieval_time_estimate
    case archive_level
    when "hot_storage"
      "Immediate (< 1 minute)"
    when "warm_storage"
      "Fast (1-5 minutes)"
    when "cold_storage"
      "Standard (1-5 hours)"
    when "deep_archive"
      "Extended (12-48 hours)"
    end
  end

  def storage_cost_tier
    case archive_level
    when "hot_storage"
      "High cost, instant access"
    when "warm_storage"
      "Medium cost, quick access"
    when "cold_storage"
      "Low cost, delayed access"
    when "deep_archive"
      "Lowest cost, slow access"
    end
  end

  def archive_size_mb
    return 0 unless archived_content_body.present?

    (archived_content_body.bytesize / 1.megabyte.to_f).round(2)
  end

  def days_until_expiry
    return nil unless retention_expires_at

    ((retention_expires_at - Time.current) / 1.day).ceil
  end

  def auto_delete_if_expired!
    return false unless expired? && auto_delete_on_expiry?

    transaction do
      # Delete archived content
      update!(
        archived_content_body: nil,
        status: "failed",
        failure_reason: "Automatically deleted due to retention policy expiry"
      )

      # Log the deletion
      Rails.logger.info "Auto-deleted expired archive #{id} for content repository #{content_repository_id}"
    end

    true
  end

  def extend_retention!(new_expiry_date:, extended_by:, reason:)
    update!(
      retention_expires_at: new_expiry_date,
      retention_extended_by: extended_by,
      retention_extension_reason: reason,
      retention_extended_at: Time.current
    )
  end

  def metadata_summary
    return {} unless metadata_backup.present?

    {
      total_versions: metadata_backup["versions"]&.length || 0,
      total_tags: metadata_backup["tags"]&.length || 0,
      approval_history: metadata_backup["approvals"]&.length || 0,
      revision_count: metadata_backup["revisions"]&.length || 0,
      original_created_at: metadata_backup.dig("repository_data", "created_at"),
      original_updated_at: metadata_backup.dig("repository_data", "updated_at"),
      original_user: metadata_backup.dig("repository_data", "user_id")
    }
  end

  private

  def set_retention_expiry
    years = retention_period.split("_").first.to_i
    self.retention_expires_at = years.years.from_now
  end

  def set_storage_location
    date_path = Date.current.strftime("%Y/%m")
    self.storage_location = "archives/#{date_path}/#{archive_level}/#{content_repository.id}"
  end

  def schedule_archival_job
    ContentArchivalJob.perform_later(id)
  end
end
