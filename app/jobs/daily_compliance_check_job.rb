class DailyComplianceCheckJob < ApplicationJob
  queue_as :default

  def perform(compliance_requirement_id)
    requirement = ComplianceRequirement.find(compliance_requirement_id)
    Rails.logger.info "Performing daily compliance check for requirement #{requirement.id}"
    
    # Perform monitoring check
    service_result = ComplianceManagementService.call(
      user: requirement.user,
      params: { action: 'monitoring_check' }
    )
    
    # Schedule next daily check
    DailyComplianceCheckJob.set(wait: 1.day).perform_later(requirement.id)
    
    service_result
  end
end