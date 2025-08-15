class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :journeys, dependent: :destroy
  has_one_attached :avatar

  ROLES = %w[marketer team_member admin].freeze

  validates :role, inclusion: { in: ROLES }
  validates :first_name, length: { maximum: 50 }
  validates :last_name, length: { maximum: 50 }
  validates :phone, format: { with: /\A[\+]?[1-9][\d\s\-\(\)]{7,15}\z/, message: "must be a valid phone number" }, allow_blank: true
  validates :company, length: { maximum: 100 }
  validates :bio, length: { maximum: 500 }
  
  validate :avatar_validation

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  serialize :notification_preferences, coder: JSON

  def marketer?
    role == 'marketer'
  end

  def team_member?
    role == 'team_member'
  end

  def admin?
    role == 'admin'
  end

  def full_name
    [first_name, last_name].compact.join(' ').presence || email_address.split('@').first
  end

  def initials
    if first_name.present? && last_name.present?
      "#{first_name[0]}#{last_name[0]}".upcase
    else
      email_address[0..1].upcase
    end
  end

  def notification_preferences
    prefs = super || default_notification_preferences
    # Convert string values to boolean for consistency
    prefs.transform_values { |v| v == true || v == "true" }
  end

  def notification_preferences=(value)
    # Convert string values to boolean when setting
    if value.is_a?(Hash)
      value = value.transform_values { |v| v == true || v == "true" }
    end
    super(value)
  end

  # Session security methods
  def active_sessions
    sessions.active
  end

  def terminate_all_sessions!
    Rails.logger.info "Terminating all sessions for user #{id}"
    sessions.destroy_all
  end

  def terminate_other_sessions!(current_session)
    other_sessions = sessions.where.not(id: current_session.id)
    Rails.logger.info "Terminating #{other_sessions.count} other sessions for user #{id}"
    other_sessions.destroy_all
  end

  def has_suspicious_sessions?
    sessions.any?(&:suspicious_activity?)
  end

  def session_security_score
    # Calculate a security score based on session activity
    score = 100
    
    # Deduct points for suspicious sessions
    score -= sessions.count(&:suspicious_activity?) * 20
    
    # Deduct points for too many sessions
    score -= [sessions.count - 3, 0].max * 5
    
    # Deduct points for very old sessions
    old_sessions = sessions.select { |s| s.created_at < 1.month.ago }
    score -= old_sessions.count * 10
    
    [score, 0].max
  end

  private

  def avatar_validation
    return unless avatar.attached?

    if avatar.blob.byte_size > 5.megabytes
      errors.add(:avatar, 'must be less than 5MB')
    end

    unless avatar.blob.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
      errors.add(:avatar, 'must be a JPEG, PNG, GIF, or WebP image')
    end
  end

  def default_notification_preferences
    {
      email_notifications: true,
      journey_updates: true,
      marketing_emails: false,
      weekly_digest: true
    }
  end
end
