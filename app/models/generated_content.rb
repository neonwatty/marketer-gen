class GeneratedContent < ApplicationRecord
  # Associations
  belongs_to :campaign_plan
  belongs_to :created_by, class_name: 'User'
  belongs_to :approver, class_name: 'User', foreign_key: 'approved_by_id', optional: true
  
  # Self-referential associations for version control
  belongs_to :original_content, class_name: 'GeneratedContent', optional: true
  has_many :content_versions, class_name: 'GeneratedContent', foreign_key: 'original_content_id', dependent: :destroy
  
  # New version control and audit associations
  has_many :version_logs, class_name: 'ContentVersion', dependent: :destroy
  has_many :audit_logs, class_name: 'ContentAuditLog', dependent: :destroy
  
  # Approval workflow associations
  has_one :approval_workflow, dependent: :destroy
  has_many :content_feedbacks, dependent: :destroy
  
  # A/B testing associations
  has_many :control_ab_tests, class_name: 'ContentAbTest', foreign_key: 'control_content_id', dependent: :destroy
  has_many :content_ab_test_variants, dependent: :destroy
  has_many :variant_ab_tests, through: :content_ab_test_variants, source: :content_ab_test
  
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
    if original_version?
      # Original is latest if no content versions exist
      content_versions.empty?
    else
      # Version is latest if no versions have higher version number
      original_content.content_versions.where('version_number > ?', version_number).empty?
    end
  end
  
  def get_latest_version
    if original_version?
      # For original content, get latest version from content_versions or self if none exist
      content_versions.order(:version_number).last || self
    else
      # For version content, get latest from original's content_versions
      original_content.content_versions.order(:version_number).last || original_content
    end
  end
  
  def create_new_version!(user, change_summary = nil)
    transaction do
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
      
      # Create version log entry
      ContentVersion.create_version!(
        new_version,
        'created',
        user,
        change_summary || "New version created from version #{version_number}",
        { original_version_id: id }
      )
      
      # Create audit log entry
      ContentAuditLog.log_action(
        new_version,
        user,
        'create',
        nil,
        new_version.attributes.except('id', 'created_at', 'updated_at'),
        { version_created_from: version_number }
      )
      
      new_version
    end
  end
  
  def next_version_number
    if original_version?
      # For original content, the next version should be current version + 1
      # If no versions exist yet, start from 2 (since original is 1)
      max_version = content_versions.maximum(:version_number) || 1
      max_version + 1
    else
      # For version content, get the max from all versions of the original
      max_version = original_content.content_versions.maximum(:version_number) || original_content.version_number
      max_version + 1
    end
  end
  
  def version_history_chain
    if original_version?
      [self] + content_versions.order(:version_number)
    else
      [original_content] + original_content.content_versions.order(:version_number)
    end
  end
  
  # Compare this version with another version
  def compare_with_version(other_version)
    return nil unless other_version.is_a?(GeneratedContent)
    
    {
      title: {
        old: other_version.title,
        new: title,
        changed: title != other_version.title
      },
      body_content: {
        old: other_version.body_content,
        new: body_content,
        changed: body_content != other_version.body_content
      },
      content_type: {
        old: other_version.content_type,
        new: content_type,
        changed: content_type != other_version.content_type
      },
      format_variant: {
        old: other_version.format_variant,
        new: format_variant,
        changed: format_variant != other_version.format_variant
      },
      status: {
        old: other_version.status,
        new: status,
        changed: status != other_version.status
      },
      version_number: {
        old: other_version.version_number,
        new: version_number,
        changed: version_number != other_version.version_number
      },
      word_count_change: word_count - other_version.word_count,
      character_count_change: character_count - other_version.character_count
    }
  end
  
  # Rollback to a previous version (creates a new version with old content)
  def rollback_to_version!(target_version, user, reason = nil)
    return false unless target_version.is_a?(GeneratedContent)
    return false if target_version.version_number >= version_number
    
    transaction do
      # Create new version with rolled back content
      rollback_version = self.dup
      rollback_version.assign_attributes(
        title: target_version.title,
        body_content: target_version.body_content,
        content_type: target_version.content_type,
        format_variant: target_version.format_variant,
        version_number: next_version_number,
        created_by: user,
        approved_by_id: nil,
        status: 'draft',
        created_at: nil,
        updated_at: nil,
        metadata: (metadata || {}).merge(
          rolled_back_from_version: version_number,
          rolled_back_to_version: target_version.version_number,
          rollback_reason: reason,
          rollback_timestamp: Time.current
        )
      )
      rollback_version.save!
      
      # Create version log entry
      ContentVersion.create_version!(
        rollback_version,
        'rolled_back',
        user,
        reason || "Rolled back from version #{version_number} to version #{target_version.version_number}",
        { 
          target_version_id: target_version.id,
          original_version_id: id
        }
      )
      
      # Create audit log entry
      ContentAuditLog.log_action(
        rollback_version,
        user,
        'rollback',
        attributes.except('id', 'created_at', 'updated_at'),
        rollback_version.attributes.except('id', 'created_at', 'updated_at'),
        { 
          rolled_back_from: version_number,
          rolled_back_to: target_version.version_number,
          reason: reason
        }
      )
      
      rollback_version
    end
  end
  
  # Get detailed version history with audit trail
  def detailed_version_history
    history = version_history_chain
    
    history.map do |version|
      {
        version: version,
        version_logs: version.version_logs.recent.includes(:changed_by),
        audit_logs: version.audit_logs.recent.limit(10).includes(:user)
      }
    end
  end
  
  # Get content differences from previous version
  def changes_from_previous_version
    previous_version = get_previous_version
    return nil unless previous_version
    
    compare_with_version(previous_version)
  end
  
  # Get the previous version in the chain
  def get_previous_version
    all_versions = version_history_chain.sort_by(&:version_number)
    current_index = all_versions.index { |v| v.id == id }
    return nil unless current_index && current_index > 0
    
    all_versions[current_index - 1]
  end
  
  # Get the next version in the chain
  def get_next_version
    all_versions = version_history_chain.sort_by(&:version_number)
    current_index = all_versions.index { |v| v.id == id }
    return nil unless current_index && current_index < all_versions.length - 1
    
    all_versions[current_index + 1]
  end
  
  # Content management methods with audit logging
  def submit_for_review!(user = nil)
    return false unless draft?
    old_status = status
    
    transaction do
      update!(
        status: 'in_review',
        metadata: (metadata || {}).merge(submitted_for_review_at: Time.current, submitted_by: user&.id)
      )
      
      if user
        ContentVersion.create_version!(self, 'updated', user, 'Submitted for review')
        ContentAuditLog.log_action(self, user, 'update', { status: old_status }, { status: 'in_review' })
      end
    end
  end
  
  def approve!(user)
    return false unless in_review?
    old_status = status
    
    transaction do
      update!(
        status: 'approved',
        approved_by_id: user.id,
        metadata: (metadata || {}).merge(approved_at: Time.current)
      )
      
      ContentVersion.create_version!(self, 'approved', user, 'Content approved')
      ContentAuditLog.log_action(self, user, 'approve', { status: old_status }, { status: 'approved', approved_by_id: user.id })
    end
  end
  
  def reject!(user, reason = nil)
    return false unless in_review?
    old_status = status
    
    transaction do
      update!(
        status: 'rejected',
        metadata: (metadata || {}).merge(
          rejected_at: Time.current,
          rejected_by: user.id,
          rejection_reason: reason
        )
      )
      
      ContentVersion.create_version!(self, 'updated', user, reason || 'Content rejected')
      ContentAuditLog.log_action(self, user, 'update', { status: old_status }, { status: 'rejected' }, { rejection_reason: reason })
    end
  end
  
  def publish!(user = nil)
    return false unless approved?
    old_status = status
    
    transaction do
      update!(
        status: 'published',
        metadata: (metadata || {}).merge(
          published_at: Time.current,
          published_by: user&.id
        )
      )
      
      if user
        ContentVersion.create_version!(self, 'published', user, 'Content published')
        ContentAuditLog.log_action(self, user, 'publish', { status: old_status }, { status: 'published' })
      end
    end
  end
  
  def archive!(user = nil)
    old_status = status
    
    transaction do
      update!(
        status: 'archived',
        metadata: (metadata || {}).merge(
          archived_at: Time.current,
          archived_by: user&.id
        )
      )
      
      if user
        ContentVersion.create_version!(self, 'archived', user, 'Content archived')
        ContentAuditLog.log_action(self, user, 'archive', { status: old_status }, { status: 'archived' })
      end
    end
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
    
    # Use LIKE for SQLite compatibility (case-insensitive search will work)
    where(
      'LOWER(title) LIKE LOWER(?) OR LOWER(body_content) LIKE LOWER(?)',
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
    return unless created_by.present?
    
    begin
      if saved_change_to_id? # New record
        ContentVersion.create_version!(self, 'created', created_by, 'Initial content creation')
        ContentAuditLog.log_action(self, created_by, 'create', nil, attributes.except('id', 'created_at', 'updated_at'))
      elsif saved_changes.any?
        # Only log if there are actual changes (excluding timestamps)
        significant_changes = saved_changes.except('updated_at', 'created_at')
        if significant_changes.any?
          old_values = {}
          new_values = {}
          
          significant_changes.each do |key, change|
            old_values[key] = change[0]
            new_values[key] = change[1]
          end
          
          ContentVersion.create_version!(self, 'updated', created_by, 'Content updated')
          ContentAuditLog.log_action(self, created_by, 'update', old_values, new_values)
        end
      end
    rescue => e
      Rails.logger.error "Failed to create audit trail for GeneratedContent #{id}: #{e.message}"
    end
  end
  
  public
  
  # Check if content can be safely deleted
  def can_be_deleted?
    # Content cannot be deleted if:
    # 1. It's published and actively being used
    # 2. It has an active approval workflow in progress
    # 3. It has dependent content versions that would be orphaned
    # 4. It's currently being referenced by other systems
    
    return false if status == 'published'
    return false if has_active_approval_workflow?
    return false if has_dependent_versions?
    
    # Additional business rules can be added here
    true
  end
  
  private
  
  def has_active_approval_workflow?
    # Check if there's an active approval workflow
    approval_workflow&.status&.in?(['pending', 'in_progress'])
  end
  
  def has_dependent_versions?
    # Check if this content has versions that would be orphaned
    # For original content, check if it has versions
    # For version content, it can be deleted without affecting the original
    original_version? && content_versions.exists?
  end
end
