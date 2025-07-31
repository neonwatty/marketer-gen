class JourneyStepPolicy < ApplicationPolicy
  def show?
    user.present? && user_owns_journey?
  end

  def create?
    user.present? && user_owns_journey?
  end

  def new?
    create?
  end

  def update?
    user.present? && user_owns_journey?
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && user_owns_journey?
  end

  def move?
    update?
  end

  def duplicate?
    create?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.present?
        scope.joins(:journey).where(journeys: { user: user })
      else
        scope.none
      end
    end
  end

  private

  def user_owns_journey?
    record.journey.user == user
  end
end