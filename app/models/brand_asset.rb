class BrandAsset < ApplicationRecord
  belongs_to :brand
  has_one_attached :file

  # Constants
  ASSET_TYPES = %w[brand_guidelines logo style_guide document image video template].freeze
  PROCESSING_STATUSES = %w[pending processing completed failed].freeze
  
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
  validates :file, presence: true

  # Scopes
  scope :by_type, ->(type) { where(asset_type: type) }
  scope :processed, -> { where(processing_status: "completed") }
  scope :pending, -> { where(processing_status: "pending") }
  scope :failed, -> { where(processing_status: "failed") }

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

  private

  def queue_processing_job
    BrandAssetProcessingJob.perform_later(self)
  end
end
