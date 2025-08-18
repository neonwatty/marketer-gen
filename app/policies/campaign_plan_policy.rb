# frozen_string_literal: true

# Authorization policy for CampaignPlan
class CampaignPlanPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      case user.role
      when 'admin'
        scope.all
      when 'marketer'
        scope.where(user: user)
      when 'team_member'
        # Team members can see plans where they have created content
        scope.joins(:generated_contents)
             .where(generated_contents: { created_by: user })
             .distinct
      else
        scope.none
      end
    end
  end

  def show?
    admin? || owned_by_user? || has_content_access?
  end

  def create?
    marketer? || admin?
  end

  def new?
    create?
  end

  def edit?
    admin? || owned_by_user?
  end

  def update?
    edit?
  end

  def destroy?
    admin? || owned_by_user?
  end

  def generate?
    edit?
  end

  def regenerate?
    edit?
  end

  def archive?
    edit?
  end

  private

  def owned_by_user?
    record.user_id == user.id
  end

  def has_content_access?
    return false unless team_member?
    
    record.generated_contents.where(created_by: user).exists?
  end

  def admin?
    user.role == 'admin'
  end

  def marketer?
    user.role == 'marketer'
  end

  def team_member?
    user.role == 'team_member'
  end
end