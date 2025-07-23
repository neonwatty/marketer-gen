class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || password.present? }
  
  # Role-based access control
  enum :role, { marketer: 0, team_member: 1, admin: 2 }
  
  # Helper methods for role checking
  def marketer?
    role == "marketer"
  end
  
  def team_member?
    role == "team_member"
  end
  
  def admin?
    role == "admin"
  end
  
  # Password reset token generation
  def password_reset_token
    signed_id(purpose: :password_reset, expires_in: 15.minutes)
  end
  
  # Find user by password reset token
  def self.find_by_password_reset_token!(token)
    find_signed!(token, purpose: :password_reset)
  end
end
