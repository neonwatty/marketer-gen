# frozen_string_literal: true

# ReportDistributionList model for managing email distribution lists
# Supports role-based access and automatic user synchronization
class ReportDistributionList < ApplicationRecord
  belongs_to :user
  belongs_to :brand

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :brand_id }

  validate :valid_email_addresses
  validate :valid_user_ids
  validate :valid_roles

  scope :active, -> { where(is_active: true) }
  scope :auto_sync, -> { where(auto_sync_roles: true) }
  scope :by_brand, ->(brand) { where(brand: brand) }

  before_validation :set_defaults
  before_save :sync_role_users, if: :should_sync_roles?

  # Get all email addresses for this distribution list
  def all_email_addresses
    emails = []

    # Add manual email addresses
    if email_addresses.present?
      emails.concat(email_addresses.split(/[,\n]/).map(&:strip).reject(&:blank?))
    end

    # Add user emails from explicit user IDs
    if user_ids.any?
      user_emails = User.where(id: user_ids).pluck(:email)
      emails.concat(user_emails)
    end

    # Add user emails from roles (if auto-sync is enabled)
    if auto_sync_roles? && roles.any?
      role_user_emails = User.where(role: roles).pluck(:email)
      emails.concat(role_user_emails)
    end

    emails.uniq.reject(&:blank?)
  end

  # Get count of recipients
  def recipient_count
    all_email_addresses.count
  end

  # Add user to distribution list
  def add_user(user)
    return false unless user.is_a?(User)

    current_ids = Array(user_ids)
    return true if current_ids.include?(user.id)

    update(user_ids: current_ids + [ user.id ])
  end

  # Remove user from distribution list
  def remove_user(user)
    user_id = user.is_a?(User) ? user.id : user.to_i
    current_ids = Array(user_ids)

    return true unless current_ids.include?(user_id)

    update(user_ids: current_ids - [ user_id ])
  end

  # Add role to distribution list
  def add_role(role)
    return false unless role.present?

    current_roles = Array(roles)
    return true if current_roles.include?(role)

    update(roles: current_roles + [ role ])
  end

  # Remove role from distribution list
  def remove_role(role)
    current_roles = Array(roles)
    return true unless current_roles.include?(role)

    update(roles: current_roles - [ role ])
  end

  # Sync users based on roles
  def sync_role_users!
    return unless auto_sync_roles? && roles.any?

    role_user_ids = User.where(role: roles).pluck(:id)
    current_user_ids = Array(user_ids)

    # Add role users that aren't explicitly added
    new_user_ids = (role_user_ids + current_user_ids).uniq

    update(user_ids: new_user_ids) if new_user_ids != current_user_ids
  end

  # Get users from roles
  def role_users
    return User.none unless roles.any?

    User.where(role: roles)
  end

  # Get explicit users
  def explicit_users
    return User.none unless user_ids.any?

    User.where(id: user_ids)
  end

  # Get all users (explicit + role-based)
  def all_users
    user_scope = User.none

    user_scope = user_scope.or(explicit_users) if user_ids.any?
    user_scope = user_scope.or(role_users) if auto_sync_roles? && roles.any?

    user_scope.distinct
  end

  # Preview recipients
  def preview_recipients
    {
      email_addresses: email_addresses&.split(/[,\n]/)&.map(&:strip)&.reject(&:blank?) || [],
      explicit_users: explicit_users.pluck(:email),
      role_users: auto_sync_roles? ? role_users.pluck(:email) : [],
      total_count: recipient_count
    }
  end

  # Clone distribution list
  def duplicate(new_name: nil)
    dup.tap do |copy|
      copy.name = new_name || "#{name} (Copy)"
      copy.save!
    end
  end

  # Available roles for the brand's users
  def available_roles
    brand.users.distinct.pluck(:role).compact.sort
  rescue StandardError
    User.distinct.pluck(:role).compact.sort
  end

  # Statistics
  def self.statistics_for_brand(brand)
    lists = by_brand(brand)

    {
      total_lists: lists.count,
      active_lists: lists.active.count,
      auto_sync_lists: lists.auto_sync.count,
      total_recipients: lists.sum { |list| list.recipient_count },
      most_used_roles: lists.flat_map(&:roles).tally.sort_by { |_, count| -count }.first(5)
    }
  end

  private

  def set_defaults
    self.roles ||= []
    self.user_ids ||= []
    self.is_active = true if is_active.nil?
    self.auto_sync_roles = false if auto_sync_roles.nil?
  end

  def should_sync_roles?
    auto_sync_roles? && roles.any? && (roles_changed? || auto_sync_roles_changed?)
  end

  def sync_role_users
    sync_role_users!
  end

  def valid_email_addresses
    return unless email_addresses.present?

    emails = email_addresses.split(/[,\n]/).map(&:strip).reject(&:blank?)
    invalid_emails = emails.reject { |email| email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }

    if invalid_emails.any?
      errors.add(:email_addresses, "contains invalid email addresses: #{invalid_emails.join(', ')}")
    end
  end

  def valid_user_ids
    return unless user_ids.any?

    invalid_ids = user_ids - User.where(id: user_ids).pluck(:id)

    if invalid_ids.any?
      errors.add(:user_ids, "contains invalid user IDs: #{invalid_ids.join(', ')}")
    end
  end

  def valid_roles
    return unless roles.any?

    # Basic validation - in production, you might want to validate against a predefined list
    invalid_roles = roles.select(&:blank?)

    if invalid_roles.any?
      errors.add(:roles, "contains blank roles")
    end
  end
end
