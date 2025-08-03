# frozen_string_literal: true

# ReportCleanupJob handles cleanup of expired report exports
# Runs daily to remove old files and clean up storage
class ReportCleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    Rails.logger.info "Starting report cleanup job..."

    # Clean up expired exports
    cleanup_expired_exports

    # Clean up old exports (older than 30 days)
    cleanup_old_exports

    # Clean up orphaned files
    cleanup_orphaned_files

    Rails.logger.info "Report cleanup completed"
  end

  private

  def cleanup_expired_exports
    expired_count = 0

    ReportExport.where("expires_at < ?", Time.current).find_each do |export|
      begin
        export.cleanup_file!
        export.update!(status: "expired")
        expired_count += 1
      rescue StandardError => e
        Rails.logger.error "Failed to cleanup export #{export.id}: #{e.message}"
      end
    end

    Rails.logger.info "Cleaned up #{expired_count} expired exports"
  end

  def cleanup_old_exports
    old_count = 0

    ReportExport.where("created_at < ?", 30.days.ago).find_each do |export|
      begin
        export.cleanup_file!
        export.destroy!
        old_count += 1
      rescue StandardError => e
        Rails.logger.error "Failed to cleanup old export #{export.id}: #{e.message}"
      end
    end

    Rails.logger.info "Cleaned up #{old_count} old exports"
  end

  def cleanup_orphaned_files
    # This would implement logic to find and remove files that don't have
    # corresponding database records - implementation depends on storage strategy
    Rails.logger.info "Orphaned file cleanup not yet implemented"
  end
end
