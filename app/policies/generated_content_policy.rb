# frozen_string_literal: true

# Authorization policy for GeneratedContent
# Defines role-based access control for content management
class GeneratedContentPolicy < ApplicationPolicy
  # Scope class for filtering accessible content
  class Scope < Scope
    def resolve
      case user.role
      when 'admin'
        # Admins can see all content
        scope.all
      when 'marketer'
        # Marketers can see content they created or from their campaigns
        scope.joins(:campaign_plan)
             .where(
               'generated_contents.created_by_id = ? OR campaign_plans.user_id = ?',
               user.id, user.id
             )
      when 'team_member'
        # Team members can see content from campaigns they have access to
        # For now, limit to content they created
        scope.where(created_by: user)
      else
        # Default: no access
        scope.none
      end
    end
  end

  # Read permissions
  def index?
    true # Controlled by scope
  end

  def show?
    can_read?
  end

  # Write permissions
  def create?
    user.present? && (marketer? || admin?)
  end

  def new?
    create?
  end

  def edit?
    can_edit?
  end

  def update?
    can_edit?
  end

  def destroy?
    can_delete?
  end

  # Content workflow permissions
  def generate?
    # Can generate if can create content for the campaign
    user.present? && (marketer? || admin?) && can_access_campaign?
  end

  def regenerate?
    can_edit?
  end

  def approve?
    can_approve?
  end

  def publish?
    can_publish?
  end

  def archive?
    can_edit? || admin?
  end

  def create_variants?
    can_edit?
  end

  # Advanced permissions
  def manage_all?
    admin?
  end

  def view_analytics?
    can_read?
  end

  def export?
    can_read?
  end

  private

  def can_read?
    return false unless user.present?
    
    case user.role
    when 'admin'
      true
    when 'marketer'
      # Marketers can read content they created or from their campaigns
      owned_by_user? || campaign_owned_by_user?
    when 'team_member'
      # Team members can read content they created
      owned_by_user?
    else
      false
    end
  end

  def can_edit?
    return false unless user.present?
    return false if record.published? && !admin? # Published content can only be edited by admins
    
    case user.role
    when 'admin'
      true
    when 'marketer'
      # Marketers can edit content they created or from their campaigns
      owned_by_user? || campaign_owned_by_user?
    when 'team_member'
      # Team members can only edit content they created and it's not approved
      owned_by_user? && record.draft?
    else
      false
    end
  end

  def can_delete?
    return false unless user.present?
    return false if record.published? && !admin? # Published content can only be deleted by admins
    
    case user.role
    when 'admin'
      true
    when 'marketer'
      # Marketers can delete content they created or from their campaigns
      owned_by_user? || campaign_owned_by_user?
    when 'team_member'
      # Team members can only delete content they created and it's not approved
      owned_by_user? && record.draft?
    else
      false
    end
  end

  def can_approve?
    return false unless user.present?
    return false unless record.in_review?
    return false if owned_by_user? # Can't approve your own content
    
    case user.role
    when 'admin'
      true
    when 'marketer'
      # Marketers can approve content from their campaigns (but not their own)
      campaign_owned_by_user? && !owned_by_user?
    else
      false
    end
  end

  def can_publish?
    return false unless user.present?
    return false unless record.approved?
    
    case user.role
    when 'admin'
      true
    when 'marketer'
      # Marketers can publish content from their campaigns
      campaign_owned_by_user?
    else
      false
    end
  end

  def can_access_campaign?
    return false unless record.respond_to?(:campaign_plan)
    
    campaign = record.is_a?(CampaignPlan) ? record : record.campaign_plan
    return false unless campaign
    
    case user.role
    when 'admin'
      true
    when 'marketer'
      campaign.user_id == user.id
    when 'team_member'
      # For now, team members can only access campaigns where they created content
      # In the future, this could be expanded to support team assignments
      campaign.generated_contents.where(created_by: user).exists?
    else
      false
    end
  end

  # Helper methods
  def owned_by_user?
    record.created_by_id == user.id
  end

  def campaign_owned_by_user?
    record.campaign_plan&.user_id == user.id
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

  # Status check helpers
  def content_editable?
    record.draft? || record.in_review?
  end

  def content_approvable?
    record.in_review?
  end

  def content_publishable?
    record.approved?
  end
end