class PlanAuditLog < ApplicationRecord
  belongs_to :campaign_plan
  belongs_to :user
  belongs_to :plan_version, optional: true

  validates :action, presence: true
  validates :action, inclusion: { 
    in: %w[
      created updated submitted_for_approval approved rejected feedback_added 
      feedback_addressed feedback_resolved feedback_dismissed version_created 
      version_submitted_for_review version_approved version_rejected 
      stakeholder_invited stakeholder_removed plan_exported plan_shared
      feedback_status_changed
    ] 
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user, ->(user) { where(user: user) }
  scope :for_plan_version, ->(version) { where(plan_version: version) }
  scope :approval_related, -> { where(action: %w[submitted_for_approval approved rejected]) }
  scope :feedback_related, -> { where(action: %w[feedback_added feedback_addressed feedback_resolved feedback_dismissed]) }
  scope :version_related, -> { where(action: %w[version_created version_submitted_for_review version_approved version_rejected]) }

  before_create :capture_request_metadata

  def self.create_for_plan_update!(campaign_plan, user, changes, request = nil)
    create!(
      campaign_plan: campaign_plan,
      user: user,
      action: 'updated',
      details: {
        changed_fields: changes.keys,
        changes: changes,
        updated_at: Time.current
      },
      metadata: request_metadata(request),
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )
  end

  def self.create_for_plan_creation!(campaign_plan, user, request = nil)
    create!(
      campaign_plan: campaign_plan,
      user: user,
      action: 'created',
      details: {
        plan_name: campaign_plan.name,
        campaign_type: campaign_plan.campaign_type,
        objective: campaign_plan.objective,
        created_at: campaign_plan.created_at
      },
      metadata: request_metadata(request),
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )
  end

  def self.create_for_stakeholder_action!(campaign_plan, user, stakeholder_user, action_type, request = nil)
    create!(
      campaign_plan: campaign_plan,
      user: user,
      action: "stakeholder_#{action_type}",
      details: {
        stakeholder_id: stakeholder_user.id,
        stakeholder_name: stakeholder_user.full_name,
        stakeholder_email: stakeholder_user.email_address,
        action_performed: action_type,
        performed_at: Time.current
      },
      metadata: request_metadata(request),
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )
  end

  def self.create_for_export!(campaign_plan, user, export_format, request = nil)
    create!(
      campaign_plan: campaign_plan,
      user: user,
      action: 'plan_exported',
      details: {
        export_format: export_format,
        exported_at: Time.current,
        plan_version: campaign_plan.current_version_id
      },
      metadata: request_metadata(request),
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )
  end

  def action_description
    case action
    when 'created'
      'Campaign plan created'
    when 'updated'
      "Plan updated: #{details['changed_fields']&.join(', ')}"
    when 'submitted_for_approval'
      'Plan submitted for approval'
    when 'approved'
      'Plan approved'
    when 'rejected'
      'Plan rejected'
    when 'feedback_added'
      "Feedback added: #{details['comment_type']} (#{details['priority']} priority)"
    when 'feedback_addressed'
      'Feedback addressed by team'
    when 'feedback_resolved'
      'Feedback marked as resolved'
    when 'feedback_dismissed'
      'Feedback dismissed'
    when 'version_created'
      "Version #{details['version_number']} created"
    when 'version_submitted_for_review'
      "Version #{details['version_number']} submitted for review"
    when 'version_approved'
      "Version #{details['version_number']} approved"
    when 'version_rejected'
      "Version #{details['version_number']} rejected"
    when 'stakeholder_invited'
      "Stakeholder invited: #{details['stakeholder_name']}"
    when 'stakeholder_removed'
      "Stakeholder removed: #{details['stakeholder_name']}"
    when 'plan_exported'
      "Plan exported as #{details['export_format']}"
    when 'plan_shared'
      "Plan shared with #{details['recipient_count']} recipients"
    when 'feedback_status_changed'
      "Feedback status changed from #{details['from_status']} to #{details['to_status']}"
    else
      action.humanize
    end
  end

  def user_name
    user&.full_name || 'Unknown User'
  end

  def time_ago
    return "unknown" if created_at.nil?
    
    time_diff = Time.current - created_at
    if time_diff < 1.minute
      "less than a minute ago"
    elsif time_diff < 1.hour
      "#{(time_diff / 1.minute).to_i} minutes ago"
    elsif time_diff < 1.day
      "#{(time_diff / 1.hour).to_i} hours ago"
    else
      "#{(time_diff / 1.day).to_i} days ago"
    end
  end

  def has_plan_version?
    plan_version_id.present?
  end

  def version_number
    plan_version&.version_number
  end

  def is_significant?
    %w[created approved rejected version_approved version_rejected feedback_added].include?(action)
  end

  def involves_external_user?
    %w[stakeholder_invited stakeholder_removed plan_shared].include?(action)
  end

  def self.activity_summary(days = 30)
    recent_logs = where('plan_audit_logs.created_at >= ?', days.days.ago)
    
    {
      total_activity: recent_logs.count,
      plans_created: recent_logs.by_action('created').count,
      plans_updated: recent_logs.by_action('updated').count,
      approvals: recent_logs.by_action('version_approved').count,
      rejections: recent_logs.by_action('version_rejected').count,
      feedback_items: recent_logs.feedback_related.count,
      exports: recent_logs.by_action('plan_exported').count,
      most_active_users: recent_logs.joins(:user)
                                   .group('plan_audit_logs.user_id')
                                   .count
                                   .sort_by { |_, count| -count }
                                   .first(5)
                                   .map { |user_id, count| [User.find(user_id).full_name, count] },
      daily_activity: recent_logs.group('DATE(plan_audit_logs.created_at)').count
    }
  end

  def self.audit_trail_for_plan(campaign_plan, limit = 50)
    where(campaign_plan: campaign_plan)
      .includes(:user, :plan_version)
      .recent
      .limit(limit)
  end

  private

  def capture_request_metadata
    if defined?(Current) && Current.respond_to?(:request) && Current.request
      self.ip_address ||= Current.request.remote_ip
      self.user_agent ||= Current.request.user_agent
      self.metadata ||= self.class.request_metadata(Current.request)
    end
  end

  def self.request_metadata(request)
    return {} unless request

    {
      controller: request.controller_class&.name,
      action: request.action_name,
      method: request.method,
      path: request.path,
      referer: request.referer,
      timestamp: Time.current
    }
  end
end