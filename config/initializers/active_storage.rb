# Active Storage Configuration

Rails.application.config.after_initialize do
  # Configure direct uploads for better performance
  Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy

  # Configure variant processor (requires image_processing gem)
  Rails.application.config.active_storage.variant_processor = :mini_magick
end

# Configure CORS for direct uploads in production
Rails.application.config.after_initialize do
  if Rails.env.production?
    # CORS configuration is handled in storage.yml
    # Additional security configurations can be added here
  end
end

# Content type restrictions for security
Rails.application.config.active_storage.content_types_to_serve_as_binary = %w[
  text/html
  text/javascript
  image/svg+xml
  application/postscript
  application/x-shockwave-flash
].freeze

# Disable variant generation for certain file types
Rails.application.config.active_storage.variant_processor = :mini_magick
Rails.application.config.active_storage.analyzers = [
  ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick,
  ActiveStorage::Analyzer::ImageAnalyzer::Vips,
  ActiveStorage::Analyzer::VideoAnalyzer,
  ActiveStorage::Analyzer::AudioAnalyzer
]

# Configure previewers
Rails.application.config.active_storage.previewers = [
  ActiveStorage::Previewer::PopplerPDFPreviewer,
  ActiveStorage::Previewer::MuPDFPreviewer,
  ActiveStorage::Previewer::VideoPreviewer
]
