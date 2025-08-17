class GeneratedContent < ApplicationRecord
  # Associations
  belongs_to :campaign_plan
  belongs_to :created_by, class_name: 'User'
  belongs_to :approver, class_name: 'User', foreign_key: 'approved_by_id', optional: true
  
  # Self-referential associations for version control
  belongs_to :original_content, class_name: 'GeneratedContent', optional: true
  has_many :content_versions, class_name: 'GeneratedContent', foreign_key: 'original_content_id', dependent: :destroy
  
  # Constants
  CONTENT_TYPES = %w[
    email
    social_post
    blog_article
    ad_copy
    landing_page
    newsletter
    press_release
    white_paper
    case_study
    product_description
    video_script
    podcast_script
    infographic_text
    webinar_content
    sales_copy
    brochure
    presentation
  ].freeze
  
  FORMAT_VARIANTS = %w[
    short
    medium
    long
    standard
    extended
    summary
    detailed
    brief
    comprehensive
  ].freeze
  
  STATUSES = %w[
    draft
    in_review
    approved
    published
    archived
    rejected
  ].freeze
  
  # Validations
  validates :content_type, presence: true, inclusion: { in: CONTENT_TYPES }
  validates :title, presence: true, length: { maximum: 255 }
  validates :body_content, presence: true, length: { minimum: 10, maximum: 50000 }
  validates :format_variant, inclusion: { in: FORMAT_VARIANTS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :version_number, presence: true, numericality: { greater_than: 0 }
  
  # Custom validations
  validate :original_content_must_be_different_record
  validate :version_number_consistency
  validate :content_length_by_variant
  
  # JSON serialization
  serialize :metadata, coder: JSON
  
  # Scopes
  scope :by_content_type, ->(type) { where(content_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_format_variant, ->(variant) { where(format_variant: variant) }
  scope :by_campaign, ->(campaign_id) { where(campaign_plan_id: campaign_id) }
  scope :current_versions, -> { where(original_content_id: nil) }
  scope :version_history, -> { where.not(original_content_id: nil) }
  scope :draft, -> { where(status: 'draft') }
  scope :approved, -> { where(status: 'approved') }
  scope :published, -> { where(status: 'published') }
  scope :archived, -> { where(status: 'archived') }
  scope :in_review, -> { where(status: 'in_review') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_creator, ->(user_id) { where(created_by_id: user_id) }
  scope :pending_approval, -> { where(status: 'in_review') }
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  
  # Callbacks
  before_validation :set_default_metadata, on: :create
  before_validation :set_version_number, on: :create
  after_create :create_audit_trail
  after_update :create_audit_trail, if: :saved_changes?
  
  # Soft delete functionality
  def soft_delete!
    update!(deleted_at: Time.current, status: 'archived')
  end
  
  def restore!
    update!(deleted_at: nil, status: 'draft')
  end
  
  def deleted?
    deleted_at.present?
  end
  
  # Status methods
  def draft?
    status == 'draft'
  end
  
  def in_review?
    status == 'in_review'
  end
  
  def approved?
    status == 'approved'
  end
  
  def published?
    status == 'published'
  end
  
  def archived?
    status == 'archived'
  end
  
  def rejected?
    status == 'rejected'
  end
  
  # Version control methods
  def original_version?
    original_content_id.nil?
  end
  
  def version_of?(content)
    original_content_id == content.id
  end
  
  def latest_version?
    return true if original_version?
    original_content.content_versions.where('version_number > ?', version_number).empty?
  end
  
  def get_latest_version
    return self if original_version?
    original_content.content_versions.order(:version_number).last || original_content
  end
  
  def create_new_version!(user, change_summary = nil)
    new_version = self.dup
    new_version.assign_attributes(
      original_content_id: original_version? ? id : original_content_id,
      version_number: next_version_number,
      created_by: user,
      approved_by_id: nil,
      status: 'draft',
      created_at: nil,
      updated_at: nil,
      metadata: (metadata || {}).merge(
        change_summary: change_summary,
        created_from_version: version_number
      )
    )
    new_version.save!
    new_version
  end
  
  def next_version_number
    if original_version?
      content_versions.maximum(:version_number).to_i + 1
    else
      original_content.content_versions.maximum(:version_number).to_i + 1
    end
  end
  
  def version_history_chain
    if original_version?
      [self] + content_versions.order(:version_number)
    else
      [original_content] + original_content.content_versions.order(:version_number)
    end
  end
  
  # Content management methods
  def submit_for_review!(user = nil)
    return false unless draft?
    update!(
      status: 'in_review',
      metadata: (metadata || {}).merge(submitted_for_review_at: Time.current, submitted_by: user&.id)
    )
  end
  
  def approve!(user)
    return false unless in_review?
    update!(
      status: 'approved',
      approved_by: user,
      metadata: (metadata || {}).merge(approved_at: Time.current)
    )
  end
  
  def reject!(user, reason = nil)
    return false unless in_review?
    update!(
      status: 'rejected',
      metadata: (metadata || {}).merge(
        rejected_at: Time.current,
        rejected_by: user.id,
        rejection_reason: reason
      )
    )
  end
  
  def publish!(user = nil)
    return false unless approved?
    update!(
      status: 'published',
      metadata: (metadata || {}).merge(
        published_at: Time.current,
        published_by: user&.id
      )
    )
  end
  
  def archive!(user = nil)
    update!(
      status: 'archived',
      metadata: (metadata || {}).merge(
        archived_at: Time.current,
        archived_by: user&.id
      )
    )
  end
  
  # Content analysis methods
  def word_count
    body_content.split.length
  end
  
  def character_count
    body_content.length
  end
  
  def estimated_read_time
    (word_count / 200.0).ceil # Assuming 200 words per minute
  end
  
  def content_summary
    {
      id: id,
      title: title,
      content_type: content_type,
      format_variant: format_variant,
      status: status,
      version_number: version_number,
      word_count: word_count,
      character_count: character_count,
      estimated_read_time: estimated_read_time,
      creator: created_by.full_name,
      created_at: created_at,
      updated_at: updated_at,
      is_latest_version: latest_version?,
      campaign_name: campaign_plan.name
    }
  end
  
  # Platform-specific metadata helpers
  def platform_settings(platform = nil)
    return metadata&.dig('platform_settings') || {} if platform.nil?
    metadata&.dig('platform_settings', platform.to_s) || {}
  end
  
  def set_platform_settings(platform, settings)
    self.metadata = (metadata || {})
    self.metadata['platform_settings'] ||= {}
    self.metadata['platform_settings'][platform.to_s] = settings
    save!
  end
  
  # Search and filtering
  def self.search_content(query)
    return all if query.blank?
    
    where(
      'title ILIKE ? OR body_content ILIKE ?',
      "%#{query}%", "%#{query}%"
    )
  end
  
  def self.for_campaign_and_type(campaign_id, content_type)
    by_campaign(campaign_id).by_content_type(content_type)
  end
  
  def self.content_analytics_summary
    {
      total_content: count,
      by_type: group(:content_type).count,
      by_status: group(:status).count,
      by_format: group(:format_variant).count,
      total_versions: version_history.count,
      avg_versions_per_content: version_history.count.to_f / current_versions.count,
      recent_activity: recent.limit(10).pluck(:id, :title, :updated_at)
    }
  end
  
  private
  
  def set_default_metadata
    self.metadata ||= {
      creation_source: 'manual',
      auto_generated: false,
      platform_settings: {}
    }
  end
  
  def set_version_number
    return if version_number.present?
    
    if original_content_id.present?
      # This is a new version of existing content
      self.version_number = original_content.content_versions.maximum(:version_number).to_i + 1
    else
      # This is original content
      self.version_number = 1
    end
  end
  
  def original_content_must_be_different_record
    return unless original_content_id.present?
    
    if original_content_id == id
      errors.add(:original_content_id, "cannot reference itself")
    end
  end
  
  def version_number_consistency
    return unless original_content_id.present? && original_content.present?
    
    existing_version = original_content.content_versions.find_by(version_number: version_number)
    if existing_version.present? && existing_version.id != id
      errors.add(:version_number, "already exists for this content")
    end
  end
  
  def content_length_by_variant
    return unless body_content.present? && format_variant.present?
    
    min_lengths = {
      'short' => 10,
      'brief' => 10,
      'summary' => 50,
      'medium' => 100,
      'standard' => 100,
      'long' => 500,
      'extended' => 1000,
      'detailed' => 1000,
      'comprehensive' => 2000
    }
    
    min_length = min_lengths[format_variant] || 10
    if body_content.length < min_length
      errors.add(:body_content, "must be at least #{min_length} characters for #{format_variant} format")
    end
  end
  
  def create_audit_trail
    # This would typically create an audit log entry
    # For now, we'll just log the action
    Rails.logger.info "GeneratedContent #{id} #{new_record? ? 'created' : 'updated'} by user #{created_by_id}"
  end
end
