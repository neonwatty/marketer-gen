# frozen_string_literal: true

# Model for detailed audit logging of all content changes
class ContentAuditLog < ApplicationRecord
  belongs_to :generated_content
  belongs_to :user
  
  # Actions that can be audited
  AUDIT_ACTIONS = %w[
    create
    update
    delete
    approve
    publish
    archive
    regenerate
    rollback
    restore
    view
    export
    share
  ].freeze
  
  validates :action, presence: true, inclusion: { in: AUDIT_ACTIONS }
  validates :user, presence: true
  validates :generated_content, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :for_content, ->(content_id) { where(generated_content_id: content_id) }
  scope :significant_changes, -> { where(action: %w[create update approve publish archive delete]) }
  scope :within_timeframe, ->(start_time, end_time) { where(created_at: start_time..end_time) }
  
  # Create an audit log entry
  def self.log_action(generated_content, user, action, old_values = nil, new_values = nil, metadata = {})
    # Get request context if available
    request_context = Current.respond_to?(:request) && Current.request ? {
      ip_address: Current.request.remote_ip,
      user_agent: Current.request.user_agent
    } : {}
    
    create!(
      generated_content: generated_content,
      user: user,
      action: action,
      old_values: old_values,
      new_values: new_values,
      ip_address: request_context[:ip_address],
      user_agent: request_context[:user_agent],
      metadata: metadata
    )
  end
  
  # Get changes summary for display
  def changes_summary
    return 'No changes recorded' if old_values.blank? && new_values.blank?
    
    changes = []
    
    if old_values.present? && new_values.present?
      # Compare old and new values
      new_values.each do |key, new_value|
        old_value = old_values[key]
        if old_value != new_value
          changes << "#{key.humanize}: '#{old_value}' → '#{new_value}'"
        end
      end
    elsif new_values.present?
      # New creation
      changes << "Created with: #{new_values.keys.map(&:humanize).join(', ')}"
    elsif old_values.present?
      # Deletion
      changes << "Removed: #{old_values.keys.map(&:humanize).join(', ')}"
    end
    
    changes.join('; ')
  end
  
  # Get human readable action description
  def action_description
    case action
    when 'create'
      'Content created'
    when 'update'
      'Content updated'
    when 'delete'
      'Content deleted'
    when 'approve'
      'Content approved'
    when 'publish'
      'Content published'
    when 'archive'
      'Content archived'
    when 'regenerate'
      'Content regenerated'
    when 'rollback'
      'Content rolled back to previous version'
    when 'restore'
      'Content restored from archive'
    when 'view'
      'Content viewed'
    when 'export'
      'Content exported'
    when 'share'
      'Content shared'
    else
      action.humanize
    end
  end
  
  # Check if this is a significant change
  def significant_change?
    %w[create update approve publish archive delete regenerate rollback].include?(action)
  end
  
  # Get time ago in human readable format
  def time_ago
    time_diff = Time.current - created_at
    case time_diff
    when 0..59
      "#{time_diff.to_i} seconds ago"
    when 60..3599
      "#{(time_diff / 60).to_i} minutes ago"
    when 3600..86399
      "#{(time_diff / 3600).to_i} hours ago"
    else
      "#{(time_diff / 86400).to_i} days ago"
    end
  end
  
  # Export audit data
  def export_data
    {
      action: action_description,
      user: user.full_name,
      timestamp: created_at,
      changes: changes_summary,
      ip_address: ip_address,
      user_agent: user_agent,
      metadata: metadata
    }
  end
  
  # Get audit trail for a content item
  def self.audit_trail_for(generated_content_id, limit = 50)
    for_content(generated_content_id)
      .recent
      .includes(:user)
      .limit(limit)
  end
  
  # Get user activity summary
  def self.user_activity_summary(user_id, timeframe = 30.days)
    start_time = timeframe.ago
    end_time = Time.current
    
    logs = by_user(user_id).within_timeframe(start_time, end_time)
    
    {
      total_actions: logs.count,
      actions_by_type: logs.group(:action).count,
      content_items_affected: logs.distinct.count(:generated_content_id),
      most_recent_action: logs.first&.created_at,
      significant_changes: logs.significant_changes.count
    }
  end
  
  # Get content activity summary
  def self.content_activity_summary(generated_content_id)
    logs = for_content(generated_content_id)
    
    {
      total_actions: logs.count,
      actions_by_type: logs.group(:action).count,
      unique_users: logs.distinct.count(:user_id),
      first_action: logs.order(:created_at).first&.created_at,
      last_action: logs.order(:created_at).last&.created_at,
      significant_changes: logs.significant_changes.count
    }
  end
end
