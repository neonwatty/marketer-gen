class WeeklyComplianceCheckJob < ApplicationJob
  queue_as :default

  def perform(compliance_requirement_id)
    requirement = ComplianceRequirement.find(compliance_requirement_id)
    Rails.logger.info "Performing weekly compliance check for requirement #{requirement.id}"
    
    # Perform monitoring check
    service_result = ComplianceManagementService.call(
      user: requirement.user,
      params: { action: 'monitoring_check' }
    )
    
    # Schedule next weekly check
    WeeklyComplianceCheckJob.set(wait: 1.week).perform_later(requirement.id)
    
    service_result
  end
end