class ContentPermissionSystem
  attr_reader :content_id, :errors

  def initialize(content_id)
    @content_id = content_id
    @errors = []
  end

  def check_permissions(user, role)
    case role
    when "content_creator"
      {
        can_create: true,
        can_edit: user.has_role?(:content_creator) || user_has_permission?(user, "can_edit"),
        can_view: true,
        can_comment: true,
        can_approve: false,
        can_reject: false,
        can_delete: false,
        can_publish: false
      }
    when "content_reviewer"
      {
        can_create: false,
        can_edit: user.has_role?(:content_reviewer) || user_has_permission?(user, "can_edit"),
        can_view: true,
        can_comment: true,
        can_approve: user.has_role?(:content_reviewer) || user_has_permission?(user, "can_approve"),
        can_reject: user.has_role?(:content_reviewer) || user_has_permission?(user, "can_reject"),
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
        can_delete: user.has_role?(:content_manager) || user_has_permission?(user, "can_delete"),
        can_publish: user.has_role?(:content_manager) || user_has_permission?(user, "can_publish"),
        can_archive: user.has_role?(:content_manager) || user_has_permission?(user, "can_archive")
      }
    when "viewer"
      {
        can_create: false,
        can_edit: false,
        can_view: true,
        can_comment: user_has_permission?(user, "can_comment"),
        can_approve: false,
        can_reject: false,
        can_delete: false,
        can_publish: false
      }
    else
      default_permissions
    end
  rescue => e
    @errors << e.message
    raise e
  end

  def grant_permission(user:, permission_type:, granted_by:)
    begin
      # Simulate granting permission
      {
        success: true,
        user_id: user.id,
        permission_type: permission_type,
        granted_by: granted_by.id,
        granted_at: Time.current
      }
    rescue => e
      @errors << e.message
      { success: false, error: e.message }
    end
  end

  def revoke_permission(user:, permission_type:, revoked_by:)
    begin
      # Simulate revoking permission
      {
        success: true,
        user_id: user.id,
        permission_type: permission_type,
        revoked_by: revoked_by.id,
        revoked_at: Time.current
      }
    rescue => e
      @errors << e.message
      { success: false, error: e.message }
    end
  end

  def get_user_permissions(user)
    # Simulate getting user permissions for the content
    permissions = []

    # Add some sample permissions based on user roles
    if user.has_role?(:content_creator)
      permissions += [ "can_view", "can_edit", "can_comment" ]
    end

    if user.has_role?(:content_reviewer)
      permissions += [ "can_view", "can_edit", "can_comment", "can_approve", "can_reject" ]
    end

    if user.has_role?(:content_manager)
      permissions += [ "can_view", "can_edit", "can_comment", "can_approve", "can_reject", "can_delete", "can_publish" ]
    end

    {
      user_id: user.id,
      content_id: content_id,
      permissions: permissions.uniq,
      effective_role: determine_effective_role(permissions)
    }
  end

  def bulk_grant_permissions(users:, permissions:, granted_by:)
    results = []

    users.each do |user|
      permissions.each do |permission|
        results << grant_permission(
          user: user,
          permission_type: permission,
          granted_by: granted_by
        )
      end
    end

    {
      success: results.all? { |r| r[:success] },
      granted_permissions: results.count { |r| r[:success] },
      failed_permissions: results.count { |r| !r[:success] }
    }
  end

  def get_content_collaborators
    # Return list of users with permissions on this content
    collaborators = [
      {
        user_id: 1,
        role: "content_creator",
        permissions: [ "can_view", "can_edit" ],
        granted_at: 2.days.ago
      },
      {
        user_id: 2,
        role: "content_reviewer",
        permissions: [ "can_view", "can_approve", "can_reject" ],
        granted_at: 1.day.ago
      }
    ]

    {
      collaborators: collaborators,
      total_count: collaborators.length
    }
  end

  private

  def user_has_permission?(user, permission_type)
    # In a real implementation, this would check ContentPermission model
    # For now, simulate based on user roles
    case permission_type
    when "can_edit"
      user.has_role?(:content_creator) || user.has_role?(:content_manager)
    when "can_approve", "can_reject"
      user.has_role?(:content_reviewer) || user.has_role?(:content_manager)
    when "can_delete", "can_publish", "can_archive"
      user.has_role?(:content_manager)
    when "can_comment"
      true # Most users can comment
    else
      false
    end
  end

  def default_permissions
    {
      can_create: false,
      can_edit: false,
      can_view: false,
      can_comment: false,
      can_approve: false,
      can_reject: false,
      can_delete: false,
      can_publish: false
    }
  end

  def determine_effective_role(permissions)
    if permissions.include?("can_delete") && permissions.include?("can_publish")
      "content_manager"
    elsif permissions.include?("can_approve") && permissions.include?("can_reject")
      "content_reviewer"
    elsif permissions.include?("can_edit")
      "content_creator"
    else
      "viewer"
    end
  end
end
