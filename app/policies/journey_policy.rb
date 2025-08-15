class JourneyPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (user.admin? || record.user == user)
  end

  def create?
    user.present? && (user.admin? || user.marketer?)
  end

  def new?
    create?
  end

  def update?
    user.present? && (user.admin? || record.user == user)
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && (user.admin? || record.user == user)
  end

  def reorder_steps?
    update?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end
end