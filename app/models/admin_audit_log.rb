class AdminAuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :auditable, polymorphic: true, optional: true
  
  validates :action, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
  
  def self.log_action(user:, action:, auditable: nil, changes: nil, request: nil)
    create!(
      user: user,
      action: action,
      auditable: auditable,
      change_details: changes&.to_json,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )
  end
  
  def parsed_changes
    return {} unless change_details.present?
    JSON.parse(change_details)
  rescue JSON::ParserError
    {}
  end
end
