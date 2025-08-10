class BrandAssetTextExtractionJob < ApplicationJob
  queue_as :default
  
  # Retry up to 3 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Don't retry for certain errors that won't resolve with retrying
  discard_on PdfTextExtractor::UnsupportedFormatError
  discard_on PdfTextExtractor::CorruptedFileError
  discard_on PdfTextExtractor::FileTooLargeError
  
  def perform(brand_asset_id)
    brand_asset = BrandAsset.find(brand_asset_id)
    
    # Skip if asset no longer exists or doesn't need extraction
    return unless brand_asset&.extractable_file_type?
    
    # Skip if already processed successfully
    return if brand_asset.text_extracted_at.present? && brand_asset.text_extraction_error.blank?
    
    Rails.logger.info "Starting text extraction for BrandAsset ##{brand_asset.id}"
    
    extractor = PdfTextExtractor.new(brand_asset)
    
    if extractor.extractable?
      success = extractor.extract!
      
      if success
        Rails.logger.info "Successfully completed text extraction for BrandAsset ##{brand_asset.id}"
        brand_asset.mark_as_processed!
      else
        Rails.logger.error "Text extraction failed for BrandAsset ##{brand_asset.id}: #{extractor.errors.join(', ')}"
      end
    else
      Rails.logger.warn "BrandAsset ##{brand_asset.id} is not extractable, skipping text extraction"
    end
    
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "BrandAsset with ID #{brand_asset_id} not found, skipping text extraction"
  rescue => error
    Rails.logger.error "Unexpected error in text extraction job for BrandAsset ##{brand_asset_id}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    raise # Re-raise to trigger retry logic
  end
end
