class UserPolicy < ApplicationPolicy
  # Allow users to view their own profile or admins to view any profile
  def show?
    user == record || user.admin?
  end
  
  # Allow users to update their own profile or admins to update any profile
  def update?
    user == record || user.admin?
  end
  
  # Only admins can view the user index
  def index?
    user.admin?
  end
  
  # Only admins can delete users (but not themselves)
  def destroy?
    user.admin? && user != record
  end
  
  # Only admins can change user roles (but not their own)
  def change_role?
    user.admin? && user != record
  end
  
  # Only admins can suspend users (but not themselves)
  def suspend?
    user.admin? && user != record
  end
  
  # Only admins can unsuspend users
  def unsuspend?
    user.admin?
  end
  
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end