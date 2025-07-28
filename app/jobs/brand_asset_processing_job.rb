class BrandAssetProcessingJob < ApplicationJob
  queue_as :default

  def perform(brand_asset)
    return unless brand_asset.file.attached?
    
    processor = Branding::AssetProcessor.new(brand_asset)
    
    if processor.process
      Rails.logger.info "Successfully processed brand asset #{brand_asset.id}"
      
      # Trigger brand analysis if this is the first processed asset
      if brand_asset.brand.brand_assets.processed.count == 1
        BrandAnalysisJob.perform_later(brand_asset.brand)
      end
    else
      Rails.logger.error "Failed to process brand asset #{brand_asset.id}: #{processor.errors.join(', ')}"
    end
  end
end