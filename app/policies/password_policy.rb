class PasswordPolicy < ApplicationPolicy
  def new?
    true # Anyone can request a password reset
  end

  def create?
    true # Anyone can submit a password reset request
  end

  def edit?
    true # Anyone with a valid token can edit their password
  end

  def update?
    true # Anyone with a valid token can update their password
  end
end