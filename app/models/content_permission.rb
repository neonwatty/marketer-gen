class ContentPermission < ApplicationRecord
  belongs_to :content_repository
  belongs_to :user

  validates :permission_type, presence: true
  validates :user_id, uniqueness: { scope: [ :content_repository_id, :permission_type ] }

  enum permission_type: {
    can_view: 0,
    can_edit: 1,
    can_comment: 2,
    can_approve: 3,
    can_reject: 4,
    can_delete: 5,
    can_publish: 6,
    can_archive: 7,
    can_restore: 8,
    can_manage_permissions: 9
  }

  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_repository, ->(repo_id) { where(content_repository_id: repo_id) }
  scope :by_permission, ->(permission) { where(permission_type: permission) }
  scope :active, -> { where(active: true) }

  def self.grant_permission(user:, content_repository:, permission_type:, granted_by:)
    permission = find_or_initialize_by(
      user: user,
      content_repository: content_repository,
      permission_type: permission_type
    )

    permission.assign_attributes(
      active: true,
      granted_by: granted_by,
      granted_at: Time.current
    )

    permission.save!
    permission
  end

  def self.revoke_permission(user:, content_repository:, permission_type:, revoked_by:)
    permission = find_by(
      user: user,
      content_repository: content_repository,
      permission_type: permission_type
    )

    return false unless permission

    permission.update!(
      active: false,
      revoked_by: revoked_by,
      revoked_at: Time.current
    )

    true
  end

  def self.check_permissions(user, role_or_permissions)
    # Get user's permissions for content
    user_permissions = where(user: user, active: true).pluck(:permission_type)

    # Role-based permission checking
    case role_or_permissions
    when "content_creator"
      {
        can_create: true,
        can_edit: user_permissions.include?("can_edit") || user.has_role?(:content_creator),
        can_view: user_permissions.include?("can_view") || true,
        can_comment: user_permissions.include?("can_comment") || true,
        can_approve: false,
        can_reject: false,
        can_delete: false,
        can_publish: false
      }
    when "content_reviewer"
      {
        can_create: false,
        can_edit: user_permissions.include?("can_edit") || user.has_role?(:content_reviewer),
        can_view: true,
        can_comment: true,
        can_approve: user_permissions.include?("can_approve") || user.has_role?(:content_reviewer),
        can_reject: user_permissions.include?("can_reject") || user.has_role?(:content_reviewer),
        can_delete: false,
        can_publish: false
      }
    when "content_manager"
      {
        can_create: true,
        can_edit: true,
        can_view: true,
        can_comment: true,
        can_approve: true,
        can_reject: true,
        can_delete: user_permissions.include?("can_delete") || user.has_role?(:content_manager),
        can_publish: user_permissions.include?("can_publish") || user.has_role?(:content_manager),
        can_archive: user_permissions.include?("can_archive") || user.has_role?(:content_manager)
      }
    when "viewer"
      {
        can_create: false,
        can_edit: false,
        can_view: user_permissions.include?("can_view") || true,
        can_comment: user_permissions.include?("can_comment"),
        can_approve: false,
        can_reject: false,
        can_delete: false,
        can_publish: false
      }
    else
      # Direct permission checking
      permission_map = {}
      permission_types.keys.each do |perm_type|
        permission_map["can_#{perm_type.sub('can_', '')}".to_sym] = user_permissions.include?(perm_type)
      end
      permission_map
    end
  end

  def self.bulk_grant_permissions(user:, content_repository:, permissions:, granted_by:)
    transaction do
      permissions.each do |permission_type|
        grant_permission(
          user: user,
          content_repository: content_repository,
          permission_type: permission_type,
          granted_by: granted_by
        )
      end
    end
  end

  def self.copy_permissions(from_repository:, to_repository:, granted_by:)
    from_permissions = where(content_repository: from_repository, active: true)

    transaction do
      from_permissions.each do |permission|
        grant_permission(
          user: permission.user,
          content_repository: to_repository,
          permission_type: permission.permission_type,
          granted_by: granted_by
        )
      end
    end
  end

  def self.get_user_permissions(user, content_repository)
    where(user: user, content_repository: content_repository, active: true)
      .pluck(:permission_type)
  end

  def active?
    active && !expired?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def revoke!(revoked_by:, reason: nil)
    update!(
      active: false,
      revoked_by: revoked_by,
      revoked_at: Time.current,
      revocation_reason: reason
    )
  end

  def restore!(restored_by:, reason: nil)
    update!(
      active: true,
      revoked_by: nil,
      revoked_at: nil,
      revocation_reason: nil,
      restored_by: restored_by,
      restored_at: Time.current,
      restoration_reason: reason
    )
  end
end
