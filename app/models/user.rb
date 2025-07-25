class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one_attached :avatar
  has_many :activities, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || password.present? }
  
  # Profile validations
  validates :full_name, length: { maximum: 100 }
  validates :bio, length: { maximum: 500 }
  validates :phone_number, format: { with: /\A[\d\s\-\+\(\)]+\z/, allow_blank: true }
  validates :company, length: { maximum: 100 }
  validates :job_title, length: { maximum: 100 }
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_blank: true
  
  # Avatar validations
  validate :acceptable_avatar
  
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
  
  # Profile helpers
  def display_name
    full_name.presence || email_address.split("@").first
  end
  
  # Account locking
  def locked?
    locked_at.present?
  end
  
  def unlock!
    update!(locked_at: nil, lock_reason: nil)
  end
  
  def lock!(reason = "Account locked for security reasons")
    update!(locked_at: Time.current, lock_reason: reason)
  end
  
  def avatar_variant(size)
    return unless avatar.attached?
    
    case size
    when :thumb
      avatar.variant(resize_to_limit: [50, 50])
    when :medium
      avatar.variant(resize_to_limit: [200, 200])
    when :large
      avatar.variant(resize_to_limit: [400, 400])
    else
      avatar
    end
  end
  
  private
  
  def acceptable_avatar
    return unless avatar.attached?
    
    unless avatar.blob.byte_size <= 5.megabyte
      errors.add(:avatar, "is too big (should be at most 5MB)")
    end
    
    acceptable_types = ["image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp"]
    unless acceptable_types.include?(avatar.blob.content_type)
      errors.add(:avatar, "must be a JPEG, PNG, GIF, or WebP")
    end
  end
end
