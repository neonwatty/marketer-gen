# frozen_string_literal: true

# Base policy for Rails Admin interface
class RailsAdminPolicy < ApplicationPolicy
  def rails_admin?
    user&.admin?
  end

  def dashboard?
    rails_admin?
  end

  def index?
    rails_admin?
  end

  def show?
    rails_admin?
  end

  def new?
    rails_admin?
  end

  def create?
    rails_admin?
  end

  def edit?
    rails_admin?
  end

  def update?
    rails_admin?
  end

  def destroy?
    rails_admin?
  end

  def export?
    rails_admin?
  end

  def history?
    rails_admin?
  end

  def show_in_app?
    rails_admin?
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.none
      end
    end
  end
end