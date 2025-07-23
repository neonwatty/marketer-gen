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
end
