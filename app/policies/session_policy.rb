# frozen_string_literal: true

class SessionPolicy < RailsAdminPolicy
  def rails_admin?
    user&.admin?
  end

  def index?
    user&.admin?
  end

  def show?
    user&.admin? || (user == record.user)
  end

  def create?
    # Sessions are created through authentication, not admin
    false
  end

  def update?
    # Sessions shouldn't be directly updated
    false
  end

  def destroy?
    user&.admin? || (user == record.user)
  end

  def terminate?
    user&.admin? || (user == record.user)
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user
        scope.where(user: user)
      else
        scope.none
      end
    end
  end
end