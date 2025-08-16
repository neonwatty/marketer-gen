class FeedbackComment < ApplicationRecord
  belongs_to :plan_version
  belongs_to :user
  belongs_to :parent_comment, class_name: 'FeedbackComment', optional: true
  has_many :replies, class_name: 'FeedbackComment', foreign_key: 'parent_comment_id', dependent: :destroy

  validates :content, presence: true, length: { minimum: 10, maximum: 5000 }
  validates :comment_type, presence: true, inclusion: { in: %w[general suggestion concern approval] }
  validates :priority, presence: true, inclusion: { in: %w[low medium high critical] }
  validates :status, presence: true, inclusion: { in: %w[open addressed resolved dismissed] }

  scope :by_type, ->(type) { where(comment_type: type) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_status, ->(status) { where(status: status) }
  scope :open, -> { where(status: 'open') }
  scope :critical, -> { where(priority: 'critical') }
  scope :recent, -> { order(created_at: :desc) }
  scope :top_level, -> { where(parent_comment_id: nil) }
  scope :for_section, ->(section) { where(section_reference: section) }

  after_create :create_audit_log
  after_update :create_status_change_audit_log, if: :saved_change_to_status?

  def campaign_plan
    plan_version.campaign_plan
  end

  def is_reply?
    parent_comment_id.present?
  end

  def is_critical?
    priority == 'critical'
  end

  def is_open?
    status == 'open'
  end

  def is_resolved?
    status == 'resolved'
  end

  def needs_attention?
    is_open? && (is_critical? || comment_type == 'concern')
  end

  def mark_as_addressed!(user, response = nil)
    transaction do
      update_columns(status: 'addressed', metadata: (metadata || {}).merge(addressed_by: user.id, addressed_at: Time.current))
      reload
      
      if response.present?
        FeedbackComment.insert({
          parent_comment_id: id,
          plan_version_id: plan_version.id,
          user_id: user.id,
          content: response,
          comment_type: 'general',
          priority: 'low',
          status: 'open',
          created_at: Time.current,
          updated_at: Time.current
        })
      end

      PlanAuditLog.create!(
        campaign_plan: campaign_plan,
        plan_version: plan_version,
        user: user,
        action: 'feedback_addressed',
        details: {
          feedback_id: id,
          original_comment: content,
          response: response
        }
      )
    end
  end

  def mark_as_resolved!(user)
    transaction do
      update_columns(status: 'resolved', metadata: (metadata || {}).merge(resolved_by: user.id, resolved_at: Time.current))
      reload
      
      PlanAuditLog.create!(
        campaign_plan: campaign_plan,
        plan_version: plan_version,
        user: user,
        action: 'feedback_resolved',
        details: {
          feedback_id: id,
          comment: content
        }
      )
    end
  end

  def dismiss!(user, reason)
    transaction do
      update_columns(
        status: 'dismissed', 
        metadata: (metadata || {}).merge(
          dismissed_by: user.id, 
          dismissed_at: Time.current,
          dismissal_reason: reason
        )
      )
      reload
      
      PlanAuditLog.create!(
        campaign_plan: campaign_plan,
        plan_version: plan_version,
        user: user,
        action: 'feedback_dismissed',
        details: {
          feedback_id: id,
          comment: content,
          reason: reason
        }
      )
    end
  end

  def urgency_score
    case priority
    when 'critical' then 100
    when 'high' then 75
    when 'medium' then 50
    when 'low' then 25
    else 0
    end + (comment_type == 'concern' ? 25 : 0)
  end

  def formatted_section_reference
    return 'General' if section_reference.blank?
    
    section_reference.humanize.titleize
  end

  def time_since_created
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

  def can_be_edited_by?(current_user)
    user == current_user && created_at > 30.minutes.ago && status == 'open'
  end

  def self.grouped_by_section
    group(:section_reference).count
  end

  def self.summary_stats
    {
      total: count,
      open: open.count,
      critical: critical.count,
      by_type: group(:comment_type).count,
      by_priority: group(:priority).count,
      by_status: group(:status).count
    }
  end

  private

  def create_audit_log
    PlanAuditLog.create!(
      campaign_plan: campaign_plan,
      plan_version: plan_version,
      user: user,
      action: 'feedback_added',
      details: {
        feedback_id: id,
        comment_type: comment_type,
        priority: priority,
        section: section_reference,
        content_preview: content.truncate(100)
      }
    )
  end

  def create_status_change_audit_log
    PlanAuditLog.create!(
      campaign_plan: campaign_plan,
      plan_version: plan_version,
      user: (defined?(Current) && Current.respond_to?(:user) && Current.user) || user, # Use current user if available, fallback to comment author
      action: 'feedback_status_changed',
      details: {
        feedback_id: id,
        from_status: status_before_last_save,
        to_status: status,
        changed_at: Time.current
      }
    )
  end
end