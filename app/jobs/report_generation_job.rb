# frozen_string_literal: true

# ReportGenerationJob handles background generation of reports and exports
# Ensures report generation doesn't block the user interface
class ReportGenerationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(custom_report_id:, export_format:, export_id: nil, user_id: nil, schedule_id: nil)
    @custom_report = CustomReport.find(custom_report_id)
    @export_format = export_format
    @export_id = export_id
    @user = User.find(user_id) if user_id
    @schedule_id = schedule_id

    Rails.logger.info "Starting report generation for report #{custom_report_id}, format: #{export_format}"

    # Find or create export record
    @report_export = find_or_create_export

    # Update status to processing
    @report_export.update!(status: "processing")

    begin
      # Generate report data
      generation_service = Reports::ReportGenerationService.new(@custom_report, user: @user)
      result = generation_service.generate

      unless result.success?
        raise StandardError, "Report generation failed: #{result.error_message}"
      end

      # Create file export
      export_service = Reports::ExportService.new(@report_export, result.data)
      export_result = export_service.export_to_format(@export_format)

      unless export_result.success?
        raise StandardError, "Export generation failed: #{export_result.error_message}"
      end

      # Mark as completed
      @report_export.mark_completed!(
        file_path: export_result.data[:file_path],
        file_size: export_result.data[:file_size],
        filename: export_result.data[:filename]
      )

      # Send notification if this was scheduled
      send_completion_notification if @schedule_id

      Rails.logger.info "Report generation completed successfully for report #{custom_report_id}"

    rescue StandardError => e
      Rails.logger.error "Report generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      @report_export.mark_failed!(e.message)

      # Send failure notification if this was scheduled
      send_failure_notification(e.message) if @schedule_id

      raise e
    end
  end

  private

  def find_or_create_export
    if @export_id
      ReportExport.find(@export_id)
    else
      @custom_report.report_exports.create!(
        user: @user || @custom_report.user,
        export_format: @export_format,
        status: "pending",
        report_schedule_id: @schedule_id
      )
    end
  end

  def send_completion_notification
    return unless @schedule_id

    schedule = ReportSchedule.find(@schedule_id)
    recipients = schedule.email_recipient_list

    return if recipients.empty?

    ReportMailer.generation_completed(
      report_export: @report_export,
      schedule: schedule,
      recipients: recipients
    ).deliver_now
  rescue StandardError => e
    Rails.logger.error "Failed to send completion notification: #{e.message}"
  end

  def send_failure_notification(error_message)
    return unless @schedule_id

    schedule = ReportSchedule.find(@schedule_id)
    recipients = schedule.email_recipient_list

    return if recipients.empty?

    ReportMailer.generation_failed(
      custom_report: @custom_report,
      schedule: schedule,
      error_message: error_message,
      recipients: recipients
    ).deliver_now
  rescue StandardError => e
    Rails.logger.error "Failed to send failure notification: #{e.message}"
  end
end
