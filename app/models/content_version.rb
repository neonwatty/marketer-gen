# frozen_string_literal: true

# Model for tracking content version history and audit trail
class ContentVersion < ApplicationRecord
  belongs_to :generated_content
  belongs_to :changed_by, class_name: 'User'
  
  # Action types for content versioning
  ACTION_TYPES = %w[
    created
    updated
    approved
    published
    archived
    regenerated
    rolled_back
    deleted
    restored
  ].freeze
  
  validates :version_number, presence: true, 
                           numericality: { greater_than: 0 },
                           uniqueness: { scope: :generated_content_id }
  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }
  validates :timestamp, presence: true
  validates :changed_by, presence: true
  
  scope :recent, -> { order(timestamp: :desc) }
  scope :by_action, ->(action) { where(action_type: action) }
  scope :for_content, ->(content_id) { where(generated_content_id: content_id) }
  scope :by_user, ->(user_id) { where(changed_by_id: user_id) }
  
  # Get the next version number for a given content
  def self.next_version_number(generated_content_id)
    where(generated_content_id: generated_content_id).maximum(:version_number).to_i + 1
  end
  
  # Get version history for a content item
  def self.version_history_for(generated_content_id)
    for_content(generated_content_id).recent.includes(:changed_by)
  end
  
  # Create a new version entry
  def self.create_version!(generated_content, action_type, user, summary = nil, metadata = {})
    create!(
      generated_content: generated_content,
      version_number: next_version_number(generated_content.id),
      action_type: action_type,
      changed_by: user,
      changes_summary: summary,
      timestamp: Time.current,
      metadata: metadata
    )
  end
  
  # Human readable action type
  def action_description
    case action_type
    when 'created'
      'Content created'
    when 'updated'
      'Content updated'
    when 'approved'
      'Content approved'
    when 'published'
      'Content published'
    when 'archived'
      'Content archived'
    when 'regenerated'
      'Content regenerated'
    when 'rolled_back'
      'Content rolled back'
    when 'deleted'
      'Content deleted'
    when 'restored'
      'Content restored'
    else
      action_type.humanize
    end
  end
  
  # Check if this version represents a significant change
  def significant_change?
    %w[created approved published archived regenerated rolled_back].include?(action_type)
  end
  
  # Get time elapsed since this version
  def time_ago
    return 'Unknown' unless timestamp
    
    time_diff = Time.current - timestamp
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
  
  # Export version data for comparison
  def export_data
    {
      version_number: version_number,
      action: action_description,
      changed_by: changed_by.full_name,
      timestamp: timestamp,
      summary: changes_summary,
      metadata: metadata
    }
  end
end
