class BrandAsset < ApplicationRecord
  # Active Storage Association
  has_one_attached :file

  # Model Associations
  belongs_to :assetable, polymorphic: true, counter_cache: true

  # Version relationships
  belongs_to :parent_asset, class_name: "BrandAsset", optional: true
  has_many :versions, class_name: "BrandAsset", foreign_key: "parent_asset_id", dependent: :destroy

  # Enums
  enum :file_type, {
    logo: "logo",
    brand_guideline: "brand_guideline",
    style_guide: "style_guide",
    compliance_document: "compliance_document",
    brand_template: "brand_template",
    font_file: "font_file",
    color_palette: "color_palette",
    image_asset: "image_asset",
    presentation: "presentation",
    other: "other"
  }, prefix: :file_type

  enum :scan_status, {
    pending: "pending",
    scanning: "scanning",
    clean: "clean",
    infected: "infected",
    failed: "failed"
  }, prefix: :scan

  # Validations
  validates :file_type, presence: true
  validate :file_must_be_attached
  validate :file_content_type_valid
  validate :file_size_within_limits
  validate :validate_file_type_consistency
  validate :metadata_structure_valid

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_file_type, ->(type) { where(file_type: type) }
  scope :by_scan_status, ->(status) { where(scan_status: status) }
  scope :clean_files, -> { where(scan_status: "clean") }
  scope :pending_scan, -> { where(scan_status: "pending") }
  scope :infected_files, -> { where(scan_status: "infected") }
  scope :by_assetable, ->(assetable) { where(assetable: assetable) }
  scope :brand_materials, -> { where(file_type: %w[logo brand_guideline style_guide color_palette]) }
  scope :compliance_materials, -> { where(file_type: %w[compliance_document brand_guideline]) }
  scope :design_assets, -> { where(file_type: %w[logo image_asset font_file color_palette]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_purpose, ->(purpose) { where(purpose: purpose) }
  scope :with_text_extracted, -> { where.not(extracted_text: [ nil, "" ]) }
  scope :text_extraction_pending, -> { where(text_extracted_at: nil).joins("LEFT JOIN active_storage_attachments ON active_storage_attachments.record_id = brand_assets.id").where(active_storage_attachments: { record_type: "BrandAsset", name: "file" }) }
  scope :text_extraction_failed, -> { where.not(text_extraction_error: [ nil, "" ]) }

  # Callbacks
  before_save :extract_file_metadata, if: :file_changed?
  before_save :set_original_filename, if: :file_changed?
  before_save :calculate_checksum, if: :file_changed?
  after_create :schedule_virus_scan
  after_create :schedule_text_extraction, if: :extractable_file_type?

  # File Management Methods
  def file_attached?
    file.attached?
  end

  def file_url
    return nil unless file_attached?
    Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
  end

  def file_name
    return original_filename if original_filename.present?
    return nil unless file_attached?
    file.blob.filename.to_s
  end

  def human_file_size
    return nil unless file_size

    units = %w[B KB MB GB]
    size = file_size.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  def file_extension
    return nil unless file_attached?
    File.extname(file.blob.filename.to_s).downcase.delete(".")
  end

  # Content Analysis Methods
  def extractable_file_type?
    %w[brand_guideline style_guide compliance_document presentation].include?(file_type) &&
    %w[pdf doc docx ppt pptx txt].include?(file_extension)
  end

  def has_extracted_text?
    extracted_text.present?
  end

  def text_extraction_pending?
    extractable_file_type? && text_extracted_at.blank?
  end

  def text_extraction_failed?
    text_extraction_error.present?
  end

  def text_extraction_successful?
    text_extracted_at.present? && text_extraction_error.blank?
  end

  def text_preview(length = 200)
    return "No text extracted" if extracted_text.blank?
    extracted_text.length > length ? "#{extracted_text[0..length]}..." : extracted_text
  end

  def word_count
    return 0 if extracted_text.blank?
    extracted_text.split(/\s+/).count
  end

  # Security Methods
  def safe_to_use?
    scan_clean? && active?
  end

  def needs_scanning?
    scan_pending? || scan_failed?
  end

  def quarantined?
    scan_infected? || !active?
  end

  def mark_as_scanned(status, scanned_at = Time.current)
    update!(
      scan_status: status,
      scanned_at: scanned_at
    )
  end

  def mark_as_clean!
    mark_as_scanned("clean")
  end

  def mark_as_infected!
    update!(
      scan_status: "infected",
      scanned_at: Time.current,
      active: false
    )
  end

  # Brand Context Methods
  def brand_identity
    return assetable if assetable.is_a?(BrandIdentity)
    return assetable.brand_identity if assetable.respond_to?(:brand_identity)
    nil
  end

  def campaign
    return assetable if assetable.is_a?(Campaign)
    nil
  end

  # Metadata Management
  def get_metadata(key)
    metadata.dig(key.to_s)
  end

  def set_metadata(key, value)
    updated_metadata = metadata.dup
    updated_metadata[key.to_s] = value
    update(metadata: updated_metadata)
  end

  def merge_metadata(new_metadata)
    return false unless new_metadata.is_a?(Hash)

    # Ensure metadata is a hash
    current_metadata = metadata.is_a?(Hash) ? metadata : {}
    updated_metadata = current_metadata.merge(new_metadata.stringify_keys)
    result = update(metadata: updated_metadata)
    Rails.logger.debug "merge_metadata result: #{result}, errors: #{errors.full_messages}" if Rails.env.test?
    result
  end

  # File Type Helpers
  def image_file?
    %w[logo image_asset].include?(file_type) ||
    file_attached? && file.blob.content_type.start_with?("image/")
  end

  def document_file?
    %w[brand_guideline style_guide compliance_document presentation].include?(file_type) ||
    file_attached? && %w[application/pdf application/msword].any? { |type| file.blob.content_type.include?(type) }
  end

  def font_file?
    file_type_font_file? ||
    file_attached? && file.blob.content_type.start_with?("font/")
  end

  def brand_guideline_file?
    file_type_brand_guideline? || file_type_style_guide?
  end

  # Content Type Classification
  def self.supported_image_types
    %w[image/png image/jpeg image/gif image/svg+xml]
  end

  def self.supported_document_types
    %w[
      application/pdf
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/vnd.ms-powerpoint
      application/vnd.openxmlformats-officedocument.presentationml.presentation
      text/plain
    ]
  end

  def self.supported_font_types
    %w[font/woff font/woff2 font/ttf font/otf application/font-woff application/font-woff2]
  end

  # Search and Discovery
  def self.search_content(query)
    return none if query.blank?

    where("LOWER(extracted_text) LIKE ? OR LOWER(original_filename) LIKE ? OR LOWER(purpose) LIKE ?",
          "%#{query.downcase}%", "%#{query.downcase}%", "%#{query.downcase}%")
  end

  def self.by_metadata_key(key, value = nil)
    if value
      # SQLite compatible JSON extraction
      where("JSON_EXTRACT(metadata, ?) = ?", "$.#{key}", value.to_s)
    else
      # SQLite compatible JSON key check
      where("JSON_EXTRACT(metadata, ?) IS NOT NULL", "$.#{key}")
    end
  end

  scope :current_versions, -> { where(is_current_version: true) }
  scope :root_assets, -> { where(parent_asset_id: nil) }
  scope :versions_of, ->(asset_id) { where(parent_asset_id: asset_id) }

  # Processing Status
  def processed?
    processed_at.present?
  end

  def processing_needed?
    extractable_file_type? && !processed?
  end

  def mark_as_processed!
    update!(processed_at: Time.current)
  end

  def extract_text!
    return false unless extractable_file_type?

    extractor = PdfTextExtractor.new(self)
    extractor.extract!
  end

  def extract_text_async!
    return false unless extractable_file_type?

    BrandAssetTextExtractionJob.perform_later(id)
    true
  end

  # File Validation Helpers
  def supported_content_type?
    return false unless file_attached?

    content_type = file.blob.content_type
    (self.class.supported_image_types +
     self.class.supported_document_types +
     self.class.supported_font_types).include?(content_type)
  end

  # Versioning Methods
  def is_root_asset?
    parent_asset_id.nil?
  end

  def is_version?
    !is_root_asset?
  end

  def root_asset
    return self if is_root_asset?
    parent_asset
  end

  def latest_version
    if is_root_asset?
      versions.order(:version_number).last || self
    else
      parent_asset.latest_version
    end
  end

  def all_versions
    if is_root_asset?
      [ self ] + versions.order(:version_number)
    else
      parent_asset.all_versions
    end
  end

  def version_count
    if is_root_asset?
      versions.count + 1
    else
      parent_asset.version_count
    end
  end

  def create_new_version(new_file, version_notes: nil, user: nil)
    return false unless file_attached?

    transaction do
      # Create new version
      new_version = self.class.new(
        file: new_file,
        file_type: file_type,
        purpose: purpose,
        assetable: assetable,
        parent_asset: is_root_asset? ? self : parent_asset,
        version_number: next_version_number,
        is_current_version: true,
        version_notes: version_notes,
        metadata: metadata.dup
      )

      if new_version.save
        # First mark the new version as current
        new_version.update!(is_current_version: true)
        # Then mark all other versions as not current
        mark_all_versions_as_not_current_except(new_version.id)
        new_version
      else
        false
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to create new version: #{e.message}"
    false
  end

  def next_version_number
    if is_root_asset?
      # The next version should be the maximum of existing versions + 1
      # But we need to include the root asset's version number too
      max_version = [ version_number || 1, versions.maximum(:version_number) || 0 ].max
      max_version + 1
    else
      parent_asset.next_version_number
    end
  end

  def mark_all_versions_as_not_current
    mark_all_versions_as_not_current_except(nil)
  end

  def mark_all_versions_as_not_current_except(except_id)
    root_asset_to_update = is_root_asset? ? self : parent_asset

    # Update root asset (unless it's the exception)
    unless root_asset_to_update.id == except_id
      root_asset_to_update.update(is_current_version: false)
    end

    # Update all versions except the exception
    if except_id
      root_asset_to_update.versions.where.not(id: except_id).update_all(is_current_version: false)
    else
      root_asset_to_update.versions.update_all(is_current_version: false)
    end
  end

  def make_current_version!
    transaction do
      # Mark all versions as not current
      mark_all_versions_as_not_current

      # Mark this version as current
      update!(is_current_version: true)
    end
  end

  def version_history
    all_versions.map do |version|
      {
        id: version.id,
        version_number: version.version_number,
        is_current: version.is_current_version?,
        created_at: version.created_at,
        file_size: version.human_file_size,
        version_notes: version.version_notes,
        file_url: version.file_url
      }
    end
  end

  def can_create_version?
    file_attached? && (is_root_asset? || parent_asset.present?)
  end

  # Override destroy to handle versioning
  def destroy
    if is_root_asset? && versions.any?
      # If destroying root asset with versions, promote the latest version to root
      latest_ver = versions.order(:version_number).last
      if latest_ver
        latest_ver.update!(
          parent_asset_id: nil,
          is_current_version: true
        )
        # Update other versions to point to the new root
        versions.where.not(id: latest_ver.id).update_all(parent_asset_id: latest_ver.id)
      end
    end

    super
  end

  private

  def file_must_be_attached
    unless file.attached?
      errors.add(:file, "must be attached")
    end
  end

  def file_content_type_valid
    return unless file.attached?

    allowed_types = self.class.supported_image_types +
                   self.class.supported_document_types +
                   self.class.supported_font_types

    unless allowed_types.include?(file.blob.content_type)
      errors.add(:file, "must be a supported file type (images, PDFs, documents, fonts, or text files)")
    end
  end

  def file_size_within_limits
    return unless file.attached?

    file_size_bytes = file.blob.byte_size

    case file_type
    when "brand_guideline", "style_guide", "compliance_document", "presentation"
      if file_size_bytes > 10.megabytes
        errors.add(:file, "must be less than 10MB for documents")
      end
    when "logo", "image_asset"
      if file_size_bytes > 5.megabytes
        errors.add(:file, "must be less than 5MB for images")
      end
    when "font_file"
      if file_size_bytes > 2.megabytes
        errors.add(:file, "must be less than 2MB for fonts")
      end
    end
  end

  def extract_file_metadata
    return unless file_attached?

    blob = file.blob
    self.file_size = blob.byte_size
    self.content_type = blob.content_type

    # Extract additional metadata based on file type
    case blob.content_type
    when /^image\//
      extract_image_metadata(blob)
    when /^application\/pdf/
      extract_pdf_metadata(blob)
    when /^font\//
      extract_font_metadata(blob)
    end
  end

  def extract_image_metadata(blob)
    if blob.metadata.present?
      image_metadata = {
        "width" => blob.metadata["width"],
        "height" => blob.metadata["height"],
        "format" => file_extension.upcase
      }

      self.metadata = metadata.merge(image_metadata)
    end
  end

  def extract_pdf_metadata(blob)
    pdf_metadata = {
      "format" => "PDF",
      "pages" => blob.metadata&.dig("pages") || "unknown"
    }

    self.metadata = metadata.merge(pdf_metadata)
  end

  def extract_font_metadata(blob)
    font_metadata = {
      "format" => file_extension.upcase,
      "font_type" => determine_font_type
    }

    self.metadata = metadata.merge(font_metadata)
  end

  def determine_font_type
    case file_extension
    when "woff", "woff2" then "Web Font"
    when "ttf" then "TrueType"
    when "otf" then "OpenType"
    else "Unknown"
    end
  end

  def set_original_filename
    return unless file_attached?
    self.original_filename = file.blob.filename.to_s
  end

  def calculate_checksum
    return unless file_attached?
    self.checksum = file.blob.checksum
  end

  def validate_file_type_consistency
    return unless file_attached?

    blob = file.blob
    content_type = blob.content_type

    case file_type
    when "logo", "image_asset"
      unless self.class.supported_image_types.include?(content_type)
        errors.add(:file, "must be an image file for #{file_type}")
      end
    when "font_file"
      unless self.class.supported_font_types.include?(content_type)
        errors.add(:file, "must be a font file")
      end
    when "brand_guideline", "style_guide", "compliance_document", "presentation"
      unless self.class.supported_document_types.include?(content_type)
        errors.add(:file, "must be a document file (PDF, Word, PowerPoint, or text)")
      end
    end
  end

  def metadata_structure_valid
    return if metadata.blank?

    unless metadata.is_a?(Hash)
      errors.add(:metadata, "must be a valid JSON object")
    end
  end

  def file_changed?
    file.attached? &&
    (file.blob&.created_at&.> 1.minute.ago ||
     previous_changes.key?("file"))
  end

  def schedule_virus_scan
    # Placeholder for virus scanning job
    # BrandAssetScanJob.perform_later(self) if defined?(BrandAssetScanJob)
    Rails.logger.info "Scheduled virus scan for BrandAsset ##{id}"
  end

  def schedule_text_extraction
    BrandAssetTextExtractionJob.perform_later(id)
    Rails.logger.info "Scheduled text extraction for BrandAsset ##{id}"
  end
end
