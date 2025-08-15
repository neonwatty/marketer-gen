# frozen_string_literal: true

class UserPolicy < RailsAdminPolicy
  def index?
    user&.admin?
  end

  def show?
    user&.admin? || (user == record)
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin? || (user == record)
  end

  def destroy?
    # Admins can delete users, but not themselves
    user&.admin? && user != record
  end

  def rails_admin?
    user&.admin?
  end

  # Admin-specific permissions
  def change_role?
    user&.admin? && user != record
  end

  def suspend_account?
    user&.admin? && user != record
  end

  def view_sessions?
    user&.admin?
  end

  def terminate_sessions?
    user&.admin? && user != record
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user
        scope.where(id: user.id)
      else
        scope.none
      end
    end
  end

  # Custom scope for admin interface
  class AdminScope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.none
      end
    end
  end
end