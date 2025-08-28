class ComplianceReportGenerationJob < ApplicationJob
  queue_as :default

  def perform(compliance_requirement)
    Rails.logger.info "Generating compliance report for requirement #{compliance_requirement.id}"
    
    # Create a new compliance report
    report = compliance_requirement.compliance_reports.create!(
      report_type: 'automated_generation',
      generated_at: Time.current
    )
    
    Rails.logger.info "Compliance report #{report.id} generated successfully"
    report
  end
end