# frozen_string_literal: true

# ReportScheduleJob handles execution of scheduled reports
# Runs at intervals to check for due schedules and trigger generation
class ReportScheduleJob < ApplicationJob
  queue_as :schedules

  # Run every 5 minutes to check for due schedules
  def perform
    Rails.logger.info "Checking for due report schedules..."

    due_schedules = ReportSchedule.active.due_for_execution

    Rails.logger.info "Found #{due_schedules.count} due schedules"

    due_schedules.find_each do |schedule|
      begin
        execute_schedule(schedule)
      rescue StandardError => e
        Rails.logger.error "Failed to execute schedule #{schedule.id}: #{e.message}"

        schedule.update!(
          last_run_at: Time.current,
          last_error: e.message
        )
      end
    end

    # Schedule next run
    ReportScheduleJob.set(wait: 5.minutes).perform_later
  end

  private

  def execute_schedule(schedule)
    Rails.logger.info "Executing schedule #{schedule.id} for report #{schedule.custom_report.name}"

    # Generate exports for each configured format
    schedule.export_formats.each do |format|
      ReportGenerationJob.perform_later(
        custom_report_id: schedule.custom_report.id,
        export_format: format,
        user_id: schedule.user.id,
        schedule_id: schedule.id
      )
    end

    # Update schedule status
    schedule.update!(
      last_run_at: Time.current,
      run_count: schedule.run_count + 1,
      last_error: nil
    )
  end
end
