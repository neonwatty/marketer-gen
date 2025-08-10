class ContentAsset < ApplicationRecord
  # Active Storage Associations
  has_one_attached :file_attachment
  has_many_attached :supporting_files

  # Model Associations
  belongs_to :assetable, polymorphic: true, counter_cache: true
  # belongs_to :approved_by, class_name: 'User', optional: true  # Will be implemented when User model exists
  
  # Conditional associations based on assetable type
  has_one :campaign, -> { where(content_assets: { assetable_type: 'Campaign' }) }, through: :assetable, source: :assetable
  has_one :brand_identity, -> { where(content_assets: { assetable_type: 'BrandIdentity' }) }, through: :assetable, source: :assetable
  has_one :customer_journey, -> { where(content_assets: { assetable_type: 'CustomerJourney' }) }, through: :assetable, source: :assetable

  # Enums
  enum :content_type, {
    text: 'text',
    image: 'image', 
    video: 'video',
    audio: 'audio',
    document: 'document',
    template: 'template',
    link: 'link'
  }, prefix: :content

  enum :channel, {
    email: 'email',
    social_media: 'social_media',
    web: 'web',
    print: 'print',
    mobile: 'mobile',
    video_platform: 'video_platform',
    blog: 'blog',
    newsletter: 'newsletter'
  }, prefix: :channel

  enum :status, {
    draft: 'draft',
    pending_review: 'pending_review',
    approved: 'approved',
    rejected: 'rejected',
    published: 'published',
    archived: 'archived'
  }, prefix: :status

  # Validations
  validates :title, presence: true, length: { minimum: 2, maximum: 200 }
  validates :content_type, presence: true
  validates :channel, presence: true
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :file_size, numericality: { greater_than: 0 }, allow_nil: true
  validate :content_or_file_present
  validate :metadata_structure_valid
  validate :file_attachment_valid

  # Scopes
  scope :by_content_type, ->(type) { where(content_type: type) }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_stage, ->(stage) { where(stage: stage) }
  scope :published, -> { where(status: 'published') }
  scope :approved, -> { where(status: 'approved') }
  scope :draft, -> { where(status: 'draft') }
  scope :pending_review, -> { where(status: 'pending_review') }
  scope :ordered, -> { order(:position, :created_at) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_assetable, ->(assetable) { where(assetable: assetable) }
  scope :text_searchable, -> { where.not(content: [nil, '']) }

  # Callbacks
  before_save :set_file_metadata, if: :file_attachment_changed?
  before_save :set_published_at, if: :status_changed?
  after_create :set_default_position

  # Content Management Methods
  def has_file?
    file_attachment.attached?
  end

  def has_supporting_files?
    supporting_files.attached?
  end

  def file_url
    return nil unless file_attachment.attached?
    Rails.application.routes.url_helpers.rails_blob_path(file_attachment, only_path: true)
  end

  def file_name
    return nil unless file_attachment.attached?
    file_attachment.blob.filename.to_s
  end

  def human_file_size
    return nil unless file_size
    
    units = %w[B KB MB GB TB]
    size = file_size.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(1)} #{units[unit_index]}"
  end

  def content_preview(length = 100)
    return "File: #{file_name}" if content.blank? && has_file?
    return "No content" if content.blank?
    
    content.length > length ? "#{content[0..length]}..." : content
  end

  # Version Management
  def create_new_version(attributes = {})
    new_version = self.class.new(
      assetable: assetable,
      title: title,
      content_type: content_type,
      content: content,
      stage: stage,
      channel: channel,
      metadata: metadata.dup,
      description: description,
      version: version + 1,
      status: 'draft'
    )
    
    # Copy attributes if provided
    new_version.assign_attributes(attributes) if attributes.present?
    
    # Copy file attachments
    if file_attachment.attached?
      new_version.file_attachment.attach(file_attachment.blob)
    end
    
    supporting_files.each do |file|
      new_version.supporting_files.attach(file.blob)
    end
    
    new_version.save
    new_version
  end

  def duplicate_for_channel(new_channel)
    duplicate = self.class.new(
      assetable: assetable,
      title: "#{title} (#{new_channel.humanize})",
      content_type: content_type,
      content: content,
      stage: stage,
      channel: new_channel,
      metadata: metadata.dup,
      description: description,
      status: 'draft'
    )
    
    # Copy file attachments
    if file_attachment.attached?
      duplicate.file_attachment.attach(file_attachment.blob)
    end
    
    supporting_files.each do |file|
      duplicate.supporting_files.attach(file.blob)
    end
    
    duplicate.save
    duplicate
  end

  # Approval Workflow
  def submit_for_review!
    update!(status: 'pending_review')
  end

  def approve!(approver = nil)
    attributes_to_update = {
      status: 'approved',
      approved_at: Time.current
    }
    
    # Only set approved_by_id if approver is provided
    attributes_to_update[:approved_by_id] = approver.id if approver&.respond_to?(:id)
    
    update!(attributes_to_update)
  end

  def reject!
    update!(status: 'rejected')
  end

  def publish!
    return false unless status_approved? || status_draft?
    
    update!(
      status: 'published',
      published_at: Time.current
    )
  end

  def archive!
    update!(status: 'archived')
  end

  def can_be_published?
    status_approved? || status_draft?
  end

  def can_be_edited?
    status_draft? || status_rejected?
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
    
    updated_metadata = metadata.merge(new_metadata.stringify_keys)
    update(metadata: updated_metadata)
  end

  # Search and Discovery
  def self.search_content(query)
    return none if query.blank?
    
    # SQLite uses LIKE (case-sensitive), but we can use LOWER for case-insensitive search
    where("LOWER(content) LIKE ? OR LOWER(title) LIKE ? OR LOWER(description) LIKE ?",
          "%#{query.downcase}%", "%#{query.downcase}%", "%#{query.downcase}%")
  end

  def self.by_metadata_key(key, value = nil)
    if value
      where("metadata ->> ? = ?", key.to_s, value.to_s)
    else
      where("metadata ? ?", key.to_s)
    end
  end

  # Content Analysis
  def word_count
    return 0 if content.blank?
    content.split(/\s+/).count
  end

  def character_count
    return 0 if content.blank?
    content.length
  end

  def reading_time_minutes
    return 0 if content.blank?
    # Average reading speed is 200-300 words per minute, using 250
    (word_count / 250.0).ceil
  end

  # Asset Organization
  def move_to_position(new_position)
    ContentAsset.transaction do
      # Get other assets in the same context
      siblings = self.class.where(
        assetable: assetable,
        channel: channel
      ).where.not(id: id).ordered
      
      # Update positions
      siblings.where('position >= ?', new_position).update_all('position = position + 1')
      update!(position: new_position)
      
      # Reorder remaining positions
      siblings.reload.each_with_index do |asset, index|
        next if asset.id == id
        expected_position = index >= new_position ? index + 1 : index
        asset.update!(position: expected_position) if asset.position != expected_position
      end
    end
  end

  # Content Type Helpers
  def text_content?
    content_text?
  end

  def media_content?
    content_image? || content_video? || content_audio?
  end

  def file_content?
    content_document? || content_template?
  end

  def external_content?
    content_link?
  end

  private

  def content_or_file_present
    if content.blank? && !file_attachment.attached?
      errors.add(:base, "Either content text or file attachment must be present")
    end
  end

  def metadata_structure_valid
    return if metadata.blank?
    
    unless metadata.is_a?(Hash)
      errors.add(:metadata, "must be a valid JSON object")
    end
  end

  def file_attachment_valid
    return unless file_attachment.attached?
    
    blob = file_attachment.blob
    
    # Validate file size (100MB limit)
    if blob.byte_size > 100.megabytes
      errors.add(:file_attachment, "must be less than 100MB")
    end
    
    # Validate content type based on channel and type
    validate_file_content_type(blob)
  end

  def validate_file_content_type(blob)
    case content_type
    when 'image'
      unless blob.content_type.start_with?('image/')
        errors.add(:file_attachment, "must be an image file")
      end
    when 'video'
      unless blob.content_type.start_with?('video/')
        errors.add(:file_attachment, "must be a video file")
      end
    when 'audio'
      unless blob.content_type.start_with?('audio/')
        errors.add(:file_attachment, "must be an audio file")
      end
    when 'document'
      allowed_types = [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain'
      ]
      unless allowed_types.include?(blob.content_type)
        errors.add(:file_attachment, "must be a PDF, Word document, or text file")
      end
    end
  end

  def set_file_metadata
    return unless file_attachment.attached?
    
    blob = file_attachment.blob
    self.file_size = blob.byte_size
    self.mime_type = blob.content_type
    
    # Set additional metadata based on file type
    case blob.content_type
    when /^image\//
      if blob.metadata.present?
        self.metadata = metadata.merge({
          'width' => blob.metadata['width'],
          'height' => blob.metadata['height']
        })
      end
    when /^video\//
      if blob.metadata.present?
        self.metadata = metadata.merge({
          'duration' => blob.metadata['duration'],
          'width' => blob.metadata['width'],
          'height' => blob.metadata['height']
        })
      end
    end
  end

  def set_published_at
    if status_published?
      self.published_at = Time.current if published_at.blank?
    elsif !status_published?
      self.published_at = nil
    end
  end

  def set_default_position
    return if position != 0
    
    max_position = self.class.where(
      assetable: assetable,
      channel: channel
    ).maximum(:position) || 0
    
    update_column(:position, max_position + 1)
  end

  def file_attachment_changed?
    file_attachment.attached? && 
    (file_attachment.blob.created_at > 1.minute.ago || 
     previous_changes.key?('file_attachment'))
  end
end
