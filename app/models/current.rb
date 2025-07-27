class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user_agent
  attribute :ip_address
  attribute :request_id
  attribute :session_id

  delegate :user, to: :session, allow_nil: true
end
