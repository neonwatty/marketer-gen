class ComplianceAssessmentJob < ApplicationJob
  queue_as :default

  def perform(compliance_requirement_id)
    requirement = ComplianceRequirement.find(compliance_requirement_id)
    Rails.logger.info "Performing scheduled compliance assessment for requirement #{requirement.id}"
    
    # Perform assessment using the service
    service_result = ComplianceManagementService.call(
      user: requirement.user,
      params: {
        action: 'assess_compliance',
        requirement_id: requirement.id
      }
    )
    
    if service_result[:success]
      Rails.logger.info "Compliance assessment completed successfully for requirement #{requirement.id}"
    else
      Rails.logger.error "Compliance assessment failed for requirement #{requirement.id}: #{service_result[:error]}"
    end
    
    service_result
  end
end