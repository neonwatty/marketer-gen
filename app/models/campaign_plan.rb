class CampaignPlan < ApplicationRecord
  belongs_to :user
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :rejected_by, class_name: 'User', optional: true
  belongs_to :current_version, class_name: 'PlanVersion', optional: true
  
  has_many :plan_versions, dependent: :destroy
  
  # Handle circular foreign key dependency between campaign_plan and plan_versions
  before_destroy :nullify_current_version
  has_many :feedback_comments, through: :plan_versions
  has_many :plan_audit_logs, dependent: :destroy
  has_many :plan_share_tokens, dependent: :destroy
  has_many :generated_contents, dependent: :destroy
  
  CAMPAIGN_TYPES = %w[product_launch brand_awareness lead_generation customer_retention sales_promotion event_marketing].freeze
  OBJECTIVES = %w[brand_awareness lead_generation customer_acquisition customer_retention sales_growth market_expansion].freeze
  STATUSES = %w[draft generating completed failed archived].freeze
  APPROVAL_STATUSES = %w[draft pending_approval approved rejected changes_requested].freeze
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :user_id, message: "already exists for this user" }
  validates :description, length: { maximum: 2000 }
  validates :campaign_type, presence: true, inclusion: { in: CAMPAIGN_TYPES }
  validates :objective, presence: true, inclusion: { in: OBJECTIVES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :approval_status, presence: true, inclusion: { in: APPROVAL_STATUSES }
  validates :target_audience, length: { maximum: 1000 }
  validates :budget_constraints, length: { maximum: 1000 }
  validates :timeline_constraints, length: { maximum: 1000 }
  
  serialize :metadata, coder: JSON
  serialize :generated_strategy, coder: JSON
  serialize :generated_timeline, coder: JSON
  serialize :generated_assets, coder: JSON
  serialize :content_strategy, coder: JSON
  serialize :creative_approach, coder: JSON
  serialize :strategic_rationale, coder: JSON
  serialize :content_mapping, coder: JSON
  serialize :engagement_metrics, coder: JSON
  serialize :performance_data, coder: JSON
  serialize :roi_tracking, coder: JSON
  
  scope :by_campaign_type, ->(type) { where(campaign_type: type) }
  scope :by_objective, ->(objective) { where(objective: objective) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_approval_status, ->(status) { where(approval_status: status) }
  scope :completed, -> { where(status: 'completed') }
  scope :approved, -> { where(approval_status: 'approved') }
  scope :pending_approval, -> { where(approval_status: 'pending_approval') }
  scope :needs_changes, -> { where(approval_status: 'changes_requested') }
  scope :recent, -> { order(created_at: :desc) }
  scope :analytics_enabled, -> { where(analytics_enabled: true) }
  scope :with_analytics_data, -> { where.not(engagement_metrics: nil).or(where.not(performance_data: nil)) }
  scope :execution_started, -> { where.not(plan_execution_started_at: nil) }
  scope :execution_completed, -> { where.not(plan_execution_completed_at: nil) }
  
  before_validation :set_default_metadata, on: :create
  before_validation :set_default_approval_status, on: :create
  before_destroy :nullify_current_version_reference
  after_create :create_audit_log_for_creation
  after_update :create_audit_log_for_update, if: :saved_changes?
  
  def draft?
    status == 'draft'
  end
  
  def generating?
    status == 'generating'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def archived?
    status == 'archived'
  end
  
  def ready_for_generation?
    draft? && name.present? && campaign_type.present? && objective.present?
  end
  
  def has_generated_content?
    generated_summary.present? || generated_strategy.present? || 
    generated_timeline.present? || generated_assets.present? ||
    safe_field_present?(:content_strategy) || safe_field_present?(:creative_approach) ||
    safe_field_present?(:strategic_rationale) || safe_field_present?(:content_mapping)
  end
  
  def generation_progress
    return 0 unless generating? || completed?
    
    completed_sections = [
      generated_summary.present?,
      generated_strategy.present?,
      generated_timeline.present?,
      generated_assets.present?,
      safe_field_present?(:content_strategy),
      safe_field_present?(:creative_approach),
      safe_field_present?(:strategic_rationale),
      safe_field_present?(:content_mapping)
    ].count(true)
    
    (completed_sections.to_f / 8 * 100).round(0)
  end
  
  def brand_context_summary
    return {} unless brand_context.present?
    
    begin
      JSON.parse(brand_context)
    rescue JSON::ParserError
      { raw_context: brand_context }
    end
  end
  
  def budget_summary
    return {} unless budget_constraints.present?
    
    begin
      JSON.parse(budget_constraints)
    rescue JSON::ParserError
      { raw_budget: budget_constraints }
    end
  end
  
  def timeline_summary
    return {} unless timeline_constraints.present?
    
    begin
      JSON.parse(timeline_constraints)
    rescue JSON::ParserError
      { raw_timeline: timeline_constraints }
    end
  end
  
  def target_audience_summary
    return {} unless target_audience.present?
    
    begin
      JSON.parse(target_audience)
    rescue JSON::ParserError
      { raw_audience: target_audience }
    end
  end
  
  def plan_analytics
    {
      campaign_type: campaign_type,
      objective: objective,
      status: status,
      has_content: has_generated_content?,
      generation_progress: generation_progress,
      created_days_ago: created_at ? ((Time.current - created_at) / 1.day).round(1) : nil,
      last_updated: updated_at,
      content_sections: {
        summary: generated_summary.present?,
        strategy: generated_strategy.present?,
        timeline: generated_timeline.present?,
        assets: generated_assets.present?,
        content_strategy: safe_field_present?(:content_strategy),
        creative_approach: safe_field_present?(:creative_approach),
        strategic_rationale: safe_field_present?(:strategic_rationale),
        content_mapping: safe_field_present?(:content_mapping)
      }
    }
  end

  # Enhanced analytics methods
  def analytics_summary
    return {} unless analytics_enabled?

    {
      basic_analytics: plan_analytics,
      engagement_data: parsed_engagement_metrics,
      performance_data: parsed_performance_data,
      roi_data: parsed_roi_tracking,
      analytics_last_updated: analytics_last_updated_at,
      execution_status: execution_analytics_summary
    }
  end

  def parsed_engagement_metrics
    return {} unless engagement_metrics.present?
    safe_parse_json_field(:engagement_metrics)
  end

  def parsed_performance_data
    return {} unless performance_data.present?
    safe_parse_json_field(:performance_data)
  end

  def parsed_roi_tracking
    return {} unless roi_tracking.present?
    safe_parse_json_field(:roi_tracking)
  end

  def execution_analytics_summary
    {
      execution_started: plan_execution_started_at.present?,
      execution_completed: plan_execution_completed_at.present?,
      execution_duration_days: calculate_execution_duration_days,
      execution_progress_percentage: calculate_execution_progress_percentage
    }
  end

  def calculate_execution_duration_days
    return 0 unless plan_execution_started_at

    end_time = plan_execution_completed_at || Time.current
    ((end_time - plan_execution_started_at) / 1.day).round(1)
  end

  def calculate_execution_progress_percentage
    return 0 unless plan_execution_started_at
    return 100 if plan_execution_completed_at

    # Calculate based on timeline if available
    timeline_data = safe_parse_json_field(:generated_timeline)
    return 50 if timeline_data.blank? # Default progress if no timeline

    # Mock calculation based on elapsed time vs planned duration
    planned_duration = extract_planned_duration(timeline_data)
    return 50 if planned_duration.zero?

    elapsed_days = calculate_execution_duration_days
    progress = (elapsed_days / planned_duration * 100).round(1)
    [progress, 100].min
  end

  def has_analytics_data?
    engagement_metrics.present? || performance_data.present? || roi_tracking.present?
  end

  def refresh_analytics!
    return false unless analytics_enabled?

    service = PlanAnalyticsService.new(self)
    result = service.call
    
    if result[:success]
      touch(:analytics_last_updated_at)
      true
    else
      Rails.logger.error "Failed to refresh analytics for plan #{id}: #{result[:error]}"
      false
    end
  end

  def analytics_stale?
    return false unless analytics_enabled?
    return true unless analytics_last_updated_at

    # Consider analytics stale if not updated in 24 hours
    analytics_last_updated_at < 24.hours.ago
  end

  # Plan execution tracking methods
  def start_execution!
    return false if plan_execution_started_at.present?
    
    update!(plan_execution_started_at: Time.current)
    refresh_analytics! if analytics_enabled?
    true
  end

  def complete_execution!
    return false unless plan_execution_started_at.present?
    return false if plan_execution_completed_at.present?
    
    update!(plan_execution_completed_at: Time.current)
    refresh_analytics! if analytics_enabled?
    true
  end

  def execution_in_progress?
    plan_execution_started_at.present? && plan_execution_completed_at.blank?
  end

  def execution_completed?
    plan_execution_started_at.present? && plan_execution_completed_at.present?
  end

  # ROI and performance metrics
  def current_roi
    roi_data = parsed_roi_tracking
    roi_data.dig('actual_roi') || 0
  end

  def projected_roi
    roi_data = parsed_roi_tracking
    roi_data.dig('projected_roi') || 0
  end

  def engagement_score
    engagement_data = parsed_engagement_metrics
    engagement_data.dig('collaboration_score') || 0
  end

  def performance_score
    performance_data = parsed_performance_data
    quality_metrics = performance_data.dig('quality_metrics') || {}
    quality_metrics.dig('content_completeness') || generation_progress
  end

  # Content performance analytics
  def content_performance_summary
    content_data = parsed_performance_data.dig('content_performance') || {}
    
    {
      total_content_pieces: content_data.dig('content_pieces_count') || 0,
      channel_performance: content_data.dig('channel_performance') || [],
      best_performing_content: content_data.dig('best_performing_content') || {},
      content_completion_rate: content_data.dig('content_completion_rate') || 0
    }
  end

  # Timeline performance analytics
  def timeline_performance_summary
    execution_data = parsed_performance_data.dig('execution_progress') || {}
    
    {
      overall_progress: execution_data.dig('overall_progress') || 0,
      timeline_adherence: execution_data.dig('timeline_adherence') || 0,
      milestone_completion: execution_data.dig('milestone_completion') || {},
      upcoming_milestones: execution_data.dig('upcoming_milestones') || [],
      overdue_items: execution_data.dig('overdue_items') || []
    }
  end

  # Analytics reporting
  def generate_analytics_report
    return { success: false, error: 'Analytics not enabled' } unless analytics_enabled?

    service = PlanAnalyticsService.new(self)
    service.generate_analytics_report
  end

  def sync_external_analytics
    return { success: false, error: 'Analytics not enabled' } unless analytics_enabled?

    service = PlanAnalyticsService.new(self)
    service.sync_with_external_platforms
  end
  
  def can_be_archived?
    %w[completed failed].include?(status)
  end
  
  def can_be_regenerated?
    %w[completed failed archived].include?(status)
  end
  
  def archive!
    return false unless can_be_archived?
    update!(status: 'archived')
  end
  
  def mark_generation_started!
    update!(status: 'generating', metadata: (metadata || {}).merge(generation_started_at: Time.current))
  end
  
  def mark_generation_completed!
    update!(
      status: 'completed',
      metadata: (metadata || {}).merge(
        generation_completed_at: Time.current,
        generation_duration: metadata&.dig('generation_started_at') ? 
          Time.current - Time.parse(metadata['generation_started_at'].to_s) : nil
      )
    )
  end
  
  def mark_generation_failed!(error_message = nil)
    update!(
      status: 'failed',
      metadata: (metadata || {}).merge(
        generation_failed_at: Time.current,
        error_message: error_message
      )
    )
  end
  
  # Collaboration and approval methods
  def approval_draft?
    approval_status == 'draft'
  end
  
  def pending_approval?
    approval_status == 'pending_approval'
  end
  
  def approval_approved?
    approval_status == 'approved'
  end
  
  def approval_rejected?
    approval_status == 'rejected'
  end
  
  def changes_requested?
    approval_status == 'changes_requested'
  end
  
  def can_be_submitted_for_approval?
    approval_draft? && has_generated_content? && completed?
  end
  
  def can_be_approved?
    pending_approval? && !has_critical_open_feedback?
  end
  
  def can_be_rejected?
    pending_approval?
  end
  
  def approval_required?
    !approval_draft? && !approval_approved?
  end
  
  def has_feedback?
    feedback_comments.exists?
  end
  
  def has_open_feedback?
    feedback_comments.open.exists?
  end
  
  def has_critical_open_feedback?
    feedback_comments.open.critical.exists?
  end
  
  def create_version!(user, change_summary = nil, skip_audit_log = false)
    transaction do
      # Set current version as not current
      plan_versions.update_all(is_current: false)
      
      # Create new version
      version = plan_versions.create!(
        created_by: user,
        status: 'draft',
        change_summary: change_summary,
        is_current: true
      )
      
      # Create snapshot of current plan content
      version.create_snapshot_from_plan!
      
      # Update current_version_id
      update_column(:current_version_id, version.id)
      
      # Create audit log unless skipped
      unless skip_audit_log
        PlanAuditLog.create!(
          campaign_plan: self,
          plan_version: version,
          user: user,
          action: 'version_created',
          details: {
            version_number: version.version_number,
            change_summary: change_summary
          }
        )
      end
      
      version
    end
  end
  
  def submit_for_approval!(user)
    return false unless can_be_submitted_for_approval?
    
    transaction do
      # Create a new version if none exists
      version = current_version || create_version!(user, "Submitted for approval", true)
      
      version.submit_for_review!(user, true, true)
      
      update_columns(
        approval_status: 'pending_approval',
        submitted_for_approval_at: Time.current
      )
      reload
      
      PlanAuditLog.create!(
        campaign_plan: self,
        plan_version: version,
        user: user,
        action: 'submitted_for_approval',
        details: {
          submitted_at: Time.current,
          version_id: version.id
        }
      )
      
      # Trigger notification to stakeholders
      # StakeholderNotificationMailer.plan_submitted_for_approval(self).deliver_later
    end
    
    true
  end
  
  def approve!(user)
    return false unless can_be_approved?
    
    transaction do
      current_version&.approve!(user)
      
      update_columns(
        approval_status: 'approved',
        approved_at: Time.current,
        approved_by_id: user.id,
        updated_at: Time.current
      )
      
      PlanAuditLog.create!(
        campaign_plan: self,
        user: user,
        action: 'approved',
        details: {
          approved_at: Time.current,
          version_id: current_version_id
        }
      )
      
      # Trigger notification to plan owner
      # StakeholderNotificationMailer.plan_approved(self).deliver_later
    end
    
    true
  end
  
  def reject!(user, reason)
    return false unless can_be_rejected?
    
    transaction do
      current_version&.reject!(user, reason)
      
      update_columns(
        approval_status: 'rejected',
        rejected_at: Time.current,
        rejected_by_id: user.id,
        rejection_reason: reason,
        updated_at: Time.current
      )
      
      PlanAuditLog.create!(
        campaign_plan: self,
        user: user,
        action: 'rejected',
        details: {
          rejected_at: Time.current,
          reason: reason,
          version_id: current_version_id
        }
      )
      
      # Trigger notification to plan owner
      # StakeholderNotificationMailer.plan_rejected(self, reason).deliver_later
    end
    
    true
  end
  
  def request_changes!(user, requested_changes)
    transaction do
      update!(
        approval_status: 'changes_requested',
        stakeholder_notes: requested_changes
      )
      
      PlanAuditLog.create!(
        campaign_plan: self,
        user: user,
        action: 'changes_requested',
        details: {
          requested_changes: requested_changes,
          requested_at: Time.current,
          version_id: current_version_id
        }
      )
      
      # Trigger notification to plan owner
      # StakeholderNotificationMailer.changes_requested(self, requested_changes).deliver_later
    end
    
    true
  end
  
  def get_or_create_current_version!(user)
    return current_version if current_version.present?
    
    create_version!(user, 'Initial version')
  end
  
  def feedback_summary
    return {} unless has_feedback?
    
    comments = feedback_comments.includes(:user, :plan_version)
    
    {
      total_count: comments.count,
      open_count: comments.open.count,
      critical_count: comments.critical.count,
      by_type: comments.group(:comment_type).count,
      by_priority: comments.group(:priority).count,
      by_status: comments.group(:status).count,
      recent_feedback: comments.recent.limit(5).map do |comment|
        {
          id: comment.id,
          content: comment.content.truncate(100),
          user_name: comment.user.full_name,
          priority: comment.priority,
          status: comment.status,
          created_at: comment.created_at
        }
      end
    }
  end
  
  def collaboration_status
    {
      approval_status: approval_status,
      has_feedback: has_feedback?,
      open_feedback_count: feedback_comments.open.count,
      critical_feedback_count: feedback_comments.critical.count,
      current_version_number: current_version&.version_number,
      total_versions: plan_versions.count,
      last_activity: plan_audit_logs.maximum(:created_at),
      can_be_approved: can_be_approved?,
      approval_required: approval_required?
    }
  end
  
  private
  
  def nullify_current_version_reference
    if current_version_id.present?
      # Use update_columns to bypass callbacks and validations
      update_columns(current_version_id: nil)
    end
  end
  
  def set_default_metadata
    self.metadata ||= {
      created_via: 'campaign_plan_generator',
      version: '1.0'
    }
  end
  
  def set_default_approval_status
    self.approval_status ||= 'draft'
  end
  
  def safe_field_present?(field_name)
    begin
      field_value = send(field_name)
      field_value.present?
    rescue JSON::ParserError
      false
    end
  end

  # Analytics helper methods
  def safe_parse_json_field(field_name)
    field_value = send(field_name)
    return {} if field_value.blank?
    
    if field_value.is_a?(String)
      JSON.parse(field_value)
    else
      field_value
    end
  rescue JSON::ParserError
    {}
  end

  def extract_planned_duration(timeline_data)
    # Mock implementation - extract planned duration from timeline
    return 30 if timeline_data.blank? # Default 30 days
    
    # Look for duration in various timeline formats
    if timeline_data.is_a?(Hash)
      timeline_data.dig('duration_days') || timeline_data.dig(:duration_days) ||
      timeline_data.dig('total_duration') || timeline_data.dig(:total_duration) ||
      calculate_timeline_duration_from_phases(timeline_data) ||
      30
    else
      30
    end
  end

  def calculate_timeline_duration_from_phases(timeline_data)
    phases = timeline_data['phases'] || timeline_data[:phases] || timeline_data['timeline'] || timeline_data[:timeline] || []
    return 0 if phases.empty?
    
    # Sum up phase durations if available
    total_duration = 0
    phases.each do |phase|
      if phase.is_a?(Hash)
        duration = phase['duration'] || phase[:duration] || phase['days'] || phase[:days] || 7
        total_duration += duration.to_i
      end
    end
    
    total_duration > 0 ? total_duration : nil
  end
  
  def create_audit_log_for_creation
    return unless persisted?
    
    # Get current user from context if available
    current_user = (defined?(Current) && Current.respond_to?(:user) && Current.user) || user
    
    PlanAuditLog.create_for_plan_creation!(self, current_user)
  rescue => e
    Rails.logger.error "Failed to create audit log for plan creation: #{e.message}"
  end
  
  def create_audit_log_for_update
    return unless persisted? && saved_changes.any?
    
    # Get current user from context if available
    current_user = (defined?(Current) && Current.respond_to?(:user) && Current.user) || user
    
    PlanAuditLog.create_for_plan_update!(self, current_user, saved_changes)
  rescue => e
    Rails.logger.error "Failed to create audit log for plan update: #{e.message}"
  end

  # Alias methods for compatibility
  alias_method :is_approved?, :approval_approved?
  alias_method :is_rejected?, :approval_rejected?
  alias_method :needs_approval?, :approval_required?

private

  # Handle circular foreign key dependency
  def nullify_current_version
    if current_version_id.present?
      update_column(:current_version_id, nil)
    end
    
    # Set flag on all plan versions to skip campaign plan updates during destruction
    plan_versions.each do |version|
      version.skip_campaign_plan_updates = true
    end
  end
end