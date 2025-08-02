class BrandAsset < ApplicationRecord
  belongs_to :brand
  has_one_attached :file

  # Constants
  ASSET_TYPES = %w[brand_guidelines logo style_guide document image video template external_link].freeze
  PROCESSING_STATUSES = %w[pending processing completed failed].freeze
  VIRUS_SCAN_STATUSES = %w[pending scanning clean infected failed].freeze

  ALLOWED_CONTENT_TYPES = {
    document: %w[
      application/pdf
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      text/plain
      text/rtf
    ],
    image: %w[
      image/jpeg
      image/png
      image/gif
      image/svg+xml
      image/webp
    ],
    video: %w[
      video/mp4
      video/quicktime
      video/x-msvideo
    ],
    archive: %w[
      application/zip
      application/x-zip-compressed
    ]
  }.freeze

  # Validations
  validates :asset_type, presence: true, inclusion: { in: ASSET_TYPES }
  validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
  validates :virus_scan_status, inclusion: { in: VIRUS_SCAN_STATUSES }
  validates :file, presence: true, unless: -> { external_link? || skip_file_validation? }
  validates :external_url, presence: true, if: :external_link?
  validates :external_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, if: :external_link?
  validate :file_not_infected
  validate :file_size_within_limits

  # Scopes
  scope :by_type, ->(type) { where(asset_type: type) }
  scope :processed, -> { where(processing_status: "completed") }
  scope :pending, -> { where(processing_status: "pending") }
  scope :failed, -> { where(processing_status: "failed") }
  scope :virus_clean, -> { where(virus_scan_status: "clean") }
  scope :external_links, -> { where(asset_type: "external_link") }
  scope :uploaded_files, -> { where.not(asset_type: "external_link") }

  # Callbacks
  after_create_commit :queue_processing_job, unless: -> { Rails.env.test? }

  # Methods
  def document?
    ALLOWED_CONTENT_TYPES[:document].include?(content_type)
  end

  def image?
    ALLOWED_CONTENT_TYPES[:image].include?(content_type)
  end

  def video?
    ALLOWED_CONTENT_TYPES[:video].include?(content_type)
  end

  def archive?
    ALLOWED_CONTENT_TYPES[:archive].include?(content_type)
  end

  def external_link?
    asset_type == "external_link"
  end

  def skip_file_validation?
    @skip_file_validation || false
  end

  def skip_file_validation!
    @skip_file_validation = true
  end

  def processed?
    processing_status == "completed"
  end

  def processing?
    processing_status == "processing"
  end

  def failed?
    processing_status == "failed"
  end

  def file_size_mb
    return 0 unless file.attached?
    file.blob.byte_size.to_f / 1.megabyte
  end

  def content_type
    return nil unless file.attached?
    file.content_type
  end

  def mark_as_processing!
    update!(processing_status: "processing")
  end

  def mark_as_completed!
    update!(
      processing_status: "completed",
      processed_at: Time.current
    )
  end

  def mark_as_failed!(error_message = nil)
    update!(
      processing_status: "failed",
      metadata: metadata.merge(error: error_message)
    )
  end

  def update_upload_progress!(progress)
    update!(upload_progress: progress)
  end

  def update_progress(progress)
    self.upload_progress = progress
    save!
  end

  def process_with_ai
    start_time = Time.current
    
    # Determine if we need chunking based on content size
    should_chunk = extracted_text.present? && extracted_text.length > 10000
    
    analysis_service = BrandAnalysisService.new(self)
    result = analysis_service.analyze
    
    processing_time = Time.current - start_time
    
    if result[:success]
      {
        success: true,
        accuracy_score: result[:confidence],
        processing_chunks: should_chunk ? (extracted_text.length / 5000.0).ceil : 1,
        processing_time: processing_time,
        extracted_data: {
          voice_attributes: result[:characteristics][:voice_characteristics],
          brand_values: result[:characteristics][:brand_values],
          messaging_framework: result[:characteristics][:messaging_framework],
          visual_guidelines: result[:characteristics][:visual_guidelines]
        },
        analysis: result[:analysis]
      }
    else
      {
        success: false,
        error: result[:error],
        processing_time: processing_time
      }
    end
  end

  def mark_chunk_uploaded!
    increment!(:chunks_uploaded)
    update_upload_progress!((chunks_uploaded.to_f / chunk_count * 100).round) if chunk_count.present?
  end

  def upload_complete?
    chunk_count.present? && chunks_uploaded >= chunk_count
  end

  def scan_for_viruses
    # Mock virus scanning - in production this would integrate with ClamAV or similar
    return true if external_link?
    return false if original_filename&.include?("suspicious")
    true
  end

  def virus_clean?
    virus_scan_status == "clean"
  end

  def fetch_external_content
    return unless external_link? && external_url.present?

    # In production, this would fetch content from the external URL
    # For now, return mock data
    {
      success: true,
      content_type: "application/pdf",
      size: 1024,
      content: "Mock external content"
    }
  end

  def supports_chunked_upload?
    return false if external_link?
    file_size.present? && file_size > 10.megabytes
  end

  def max_chunk_size
    5.megabytes
  end

  def required_chunks
    return 0 if external_link? || file_size.blank?
    (file_size.to_f / max_chunk_size).ceil
  end

  def chunk_upload(chunk_data, chunk_number)
    # Mock chunk upload implementation
    # In production, this would handle actual file chunk processing
    return false unless supports_chunked_upload?

    # Update chunks uploaded
    self.chunks_uploaded = chunk_number
    self.chunk_count ||= required_chunks

    # Update progress
    progress = (chunks_uploaded.to_f / chunk_count * 100).round
    self.upload_progress = progress

    save!

    # Return success
    {
      success: true,
      chunk_number: chunk_number,
      progress: progress,
      complete: upload_complete?
    }
  end

  # Class methods
  def self.process_batch(assets)
    return { success: false, error: "No assets provided" } if assets.blank?
    
    start_time = Time.current
    processed_count = 0
    errors = []
    
    assets.each do |asset|
      begin
        result = asset.process_with_ai
        if result[:success]
          asset.mark_as_completed!
          processed_count += 1
        else
          asset.mark_as_failed!(result[:error])
          errors << "#{asset.original_filename}: #{result[:error]}"
        end
      rescue => e
        asset.mark_as_failed!(e.message)
        errors << "#{asset.original_filename}: #{e.message}"
      end
    end
    
    processing_time = Time.current - start_time
    
    {
      success: processed_count > 0,
      processed_count: processed_count,
      total_count: assets.count,
      processing_time: processing_time,
      errors: errors
    }
  end

  def self.create_batch(brand, file_data_array)
    assets = []
    success = true
    errors = []

    ActiveRecord::Base.transaction do
      file_data_array.each do |file_data|
        asset = brand.brand_assets.build(
          asset_type: determine_asset_type(file_data[:content_type]),
          original_filename: file_data[:filename],
          content_type: file_data[:content_type],
          processing_status: "pending"
        )

        # Skip file validation for batch creation - files will be attached later
        asset.skip_file_validation!

        if asset.save
          assets << asset
        else
          success = false
          errors << asset.errors.full_messages
        end
      end

      raise ActiveRecord::Rollback unless success
    end

    {
      success: success,
      assets: assets,
      errors: errors
    }
  end

  def self.determine_asset_type(content_type)
    case content_type
    when *ALLOWED_CONTENT_TYPES[:document]
      "document"
    when *ALLOWED_CONTENT_TYPES[:image]
      "image"
    when *ALLOWED_CONTENT_TYPES[:video]
      "video"
    else
      "document"
    end
  end

  def file_not_infected
    # Skip validation if no file and not external link
    return if !file.attached? && !external_link?

    unless scan_for_viruses
      errors.add(:file, "contains suspicious content")
    end
  end

  def file_size_within_limits
    return unless file.attached?

    max_size = 500.megabytes
    if file.blob.byte_size > max_size
      errors.add(:file, "is too large (maximum is #{max_size / 1.megabyte}MB)")
    end
  end

  private

  def queue_processing_job
    BrandAssetProcessingJob.perform_later(self)
  end
end
