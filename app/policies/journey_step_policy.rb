class JourneyStepPolicy < ApplicationPolicy
  def index?
    user.present? && (user.admin? || record.journey.user == user)
  end

  def show?
    user.present? && (user.admin? || record.journey.user == user)
  end

  def create?
    user.present? && (user.admin? || record.journey.user == user)
  end

  def new?
    create?
  end

  def update?
    user.present? && (user.admin? || record.journey.user == user)
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && (user.admin? || record.journey.user == user)
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.joins(:journey).where(journeys: { user: user })
      end
    end
  end
end