class BrandAnalysisJob < ApplicationJob
  queue_as :low_priority

  def perform(brand, additional_content = nil)
    service = Branding::AnalysisService.new(brand, additional_content)
    
    if service.analyze
      Rails.logger.info "Successfully analyzed brand #{brand.id}"
      
      # Notify user or trigger follow-up actions
      BrandAnalysisNotificationJob.perform_later(brand)
    else
      Rails.logger.error "Failed to analyze brand #{brand.id}"
    end
  end
end