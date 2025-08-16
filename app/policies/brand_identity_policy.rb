class BrandIdentityPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && record.user == user
  end

  def new?
    user.present?
  end

  def create?
    user.present?
  end

  def edit?
    user.present? && record.user == user
  end

  def update?
    user.present? && record.user == user
  end

  def destroy?
    user.present? && record.user == user
  end

  def activate?
    user.present? && record.user == user
  end

  def deactivate?
    user.present? && record.user == user && record.is_active?
  end

  def process_materials?
    user.present? && record.user == user
  end

  class Scope < Scope
    def resolve
      if user.present?
        scope.where(user: user)
      else
        scope.none
      end
    end
  end
end