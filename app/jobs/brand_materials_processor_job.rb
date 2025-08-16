class BrandMaterialsProcessorJob < ApplicationJob
  queue_as :default

  def perform(brand_identity)
    Rails.logger.info "Processing brand materials for Brand Identity ##{brand_identity.id}"
    
    begin
      processor = BrandMaterialsProcessor.new(brand_identity)
      result = processor.process_all_materials
      
      brand_identity.update!(
        processed_guidelines: result,
        status: 'active',
        brand_voice: result.dig('extracted_data', 'voice'),
        tone_guidelines: result.dig('extracted_data', 'tone'),
        messaging_framework: result.dig('extracted_data', 'messaging'),
        restrictions: result.dig('extracted_data', 'restrictions')
      )
      
      Rails.logger.info "Successfully processed brand materials for Brand Identity ##{brand_identity.id}"
    rescue => e
      Rails.logger.error "Failed to process brand materials for Brand Identity ##{brand_identity.id}: #{e.message}"
      brand_identity.update!(status: 'draft')
      raise e
    end
  end
end
