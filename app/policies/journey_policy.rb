class JourneyPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && user_owns_journey?
  end

  def create?
    user.present?
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

  def duplicate?
    show?
  end

  def publish?
    update? && record.status == 'draft'
  end

  def archive?
    update? && record.status != 'archived'
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.present?
        scope.where(user: user)
      else
        scope.none
      end
    end
  end

  private

  def user_owns_journey?
    record.user == user
  end
end