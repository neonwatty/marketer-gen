class ProfilePolicy < ApplicationPolicy
  def show?
    user.present? && (user == record || user.admin?)
  end

  def edit?
    user.present? && (user == record || user.admin?)
  end

  def update?
    user.present? && (user == record || user.admin?)
  end
end