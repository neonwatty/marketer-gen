class RailsAdminPolicy < ApplicationPolicy
  def dashboard?
    user&.admin?
  end
  
  def index?
    user&.admin?
  end
  
  def show?
    user&.admin?
  end
  
  def new?
    user&.admin?
  end
  
  def edit?
    user&.admin?
  end
  
  def destroy?
    user&.admin?
  end
  
  def export?
    user&.admin?
  end
  
  def bulk_delete?
    user&.admin?
  end
  
  def show_in_app?
    user&.admin?
  end
  
  def history_index?
    user&.admin?
  end
  
  def history_show?
    user&.admin?
  end
end