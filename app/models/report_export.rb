# frozen_string_literal: true

# ReportExport model for managing exported report files
# Tracks file generation, storage, and download analytics
class ReportExport < ApplicationRecord
  belongs_to :custom_report
  belongs_to :user
  belongs_to :report_schedule, optional: true

  validates :export_format, presence: true, inclusion: {
    in: %w[pdf excel csv powerpoint]
  }
  validates :status, presence: true, inclusion: {
    in: %w[pending processing completed failed expired]
  }
  validates :filename, presence: true, if: -> { status == "completed" }

  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :expired, -> { where(status: "expired") }
  scope :by_format, ->(format) { where(export_format: format) }
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where("expires_at > ?", Time.current) }

  before_validation :set_defaults
  before_save :set_expiration_date

  # Check if export is expired
  def expired?
    expires_at && expires_at < Time.current
  end

  # Check if export is ready for download
  def ready_for_download?
    status == "completed" && !expired? && file_path.present?
  end

  # Get file extension for the export format
  def file_extension
    case export_format
    when "pdf"
      ".pdf"
    when "excel"
      ".xlsx"
    when "csv"
      ".csv"
    when "powerpoint"
      ".pptx"
    else
      ".txt"
    end
  end

  # Get MIME type for the export format
  def mime_type
    case export_format
    when "pdf"
      "application/pdf"
    when "excel"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    when "csv"
      "text/csv"
    when "powerpoint"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    else
      "application/octet-stream"
    end
  end

  # Get human-readable file size
  def human_file_size
    return "Unknown" unless file_size

    units = %w[B KB MB GB TB]
    size = file_size.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end

  # Record a download
  def record_download!
    increment!(:download_count)
    update_column(:last_downloaded_at, Time.current)
  end

  # Mark as completed with file information
  def mark_completed!(file_path:, file_size:, filename: nil)
    update!(
      status: "completed",
      file_path: file_path,
      file_size: file_size,
      filename: filename || generate_filename,
      generated_at: Time.current,
      error_message: nil
    )
  end

  # Mark as failed with error
  def mark_failed!(error_message)
    update!(
      status: "failed",
      error_message: error_message
    )
  end

  # Clean up expired exports
  def self.cleanup_expired!
    where("expires_at < ?", Time.current).find_each do |export|
      export.cleanup_file!
      export.update!(status: "expired")
    end
  end

  # Get exports due for cleanup
  def self.due_for_cleanup
    where("expires_at < ?", 1.day.ago)
  end

  # Generate download URL (in a real app, this would use signed URLs)
  def download_url
    return nil unless ready_for_download?

    Rails.application.routes.url_helpers.download_report_export_path(self)
  end

  # Check if file exists
  def file_exists?
    file_path.present? && File.exist?(file_path)
  end

  # Remove the physical file
  def cleanup_file!
    return unless file_path.present? && File.exist?(file_path)

    File.delete(file_path)
    update_column(:file_path, nil)
  rescue StandardError => e
    Rails.logger.error "Failed to cleanup export file #{file_path}: #{e.message}"
  end

  # Get download statistics
  def self.download_statistics
    {
      total_exports: count,
      completed_exports: completed.count,
      failed_exports: failed.count,
      total_downloads: sum(:download_count),
      total_file_size: completed.sum(:file_size),
      by_format: group(:export_format).count,
      recent_activity: where("created_at > ?", 7.days.ago).count
    }
  end

  private

  def set_defaults
    self.status ||= "pending"
    self.download_count ||= 0
    self.metadata ||= {}
    self.filename ||= generate_filename if export_format.present?
  end

  def set_expiration_date
    return if expires_at.present?

    # Set expiration based on format and size
    case export_format
    when "csv"
      self.expires_at = 3.days.from_now
    when "pdf", "powerpoint"
      self.expires_at = 7.days.from_now
    when "excel"
      self.expires_at = 5.days.from_now
    else
      self.expires_at = 3.days.from_now
    end
  end

  def generate_filename
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    report_name = custom_report.name.parameterize

    "#{report_name}_#{timestamp}#{file_extension}"
  end
end
