class JourneyTemplatePolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (record.is_active? || admin_or_owner?)
  end

  def create?
    user.present?
  end

  def new?
    create?
  end

  def update?
    user.present? && admin_or_owner?
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && admin_or_owner?
  end

  def clone?
    show?
  end

  def use_template?
    show?
  end

  def builder?
    update?
  end

  def builder_react?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.present?
        # All users can see active templates
        # Admins can see all templates
        if user.admin?
          scope.all
        else
          scope.where(is_active: true)
        end
      else
        scope.none
      end
    end
  end

  private

  def admin_or_owner?
    user.admin? || (record.respond_to?(:user) && record.user == user)
  end
end