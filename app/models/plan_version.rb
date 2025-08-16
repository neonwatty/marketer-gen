class PlanVersion < ApplicationRecord
  belongs_to :campaign_plan
  belongs_to :created_by, class_name: 'User'
  has_many :feedback_comments, dependent: :destroy
  has_many :plan_audit_logs, dependent: :destroy

  validates :version_number, presence: true, uniqueness: { scope: :campaign_plan_id }
  validates :status, presence: true, inclusion: { in: %w[draft pending_review approved rejected] }

  scope :current, -> { where(is_current: true) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }

  before_validation :set_version_number, on: :create
  after_create :set_as_current_version
  after_update :update_campaign_plan_current_version, if: :saved_change_to_is_current?

  def next_version_number
    campaign_plan.plan_versions.maximum(:version_number).to_i + 1
  end

  def previous_version
    campaign_plan.plan_versions.where('version_number < ?', version_number).order(:version_number).last
  end

  def next_version
    campaign_plan.plan_versions.where('version_number > ?', version_number).order(:version_number).first
  end

  def has_feedback?
    feedback_comments.exists?
  end

  def open_feedback
    feedback_comments.where(status: 'open')
  end

  def addressed_feedback
    feedback_comments.where(status: %w[addressed resolved])
  end

  def critical_feedback
    feedback_comments.where(priority: 'critical', status: 'open')
  end

  def can_be_approved?
    status == 'pending_review' && critical_feedback.empty?
  end

  def approve!(user)
    transaction do
      update_columns(status: 'approved')
      campaign_plan.update_columns(
        approval_status: 'approved',
        approved_at: Time.current,
        approved_by_id: user.id
      )
      reload
      campaign_plan.reload
      PlanAuditLog.create!(
        campaign_plan: campaign_plan,
        plan_version: self,
        user: user,
        action: 'version_approved',
        details: {
          version_number: version_number,
          approved_at: Time.current
        }
      )
    end
  end

  def reject!(user, reason)
    transaction do
      update_columns(status: 'rejected')
      campaign_plan.update_columns(
        approval_status: 'rejected',
        rejected_at: Time.current,
        rejected_by_id: user.id,
        rejection_reason: reason
      )
      reload
      campaign_plan.reload
      PlanAuditLog.create!(
        campaign_plan: campaign_plan,
        plan_version: self,
        user: user,
        action: 'version_rejected',
        details: {
          version_number: version_number,
          reason: reason,
          rejected_at: Time.current
        }
      )
    end
  end

  def submit_for_review!(user, skip_audit_log = false, skip_campaign_plan_update = false)
    transaction do
      update_columns(status: 'pending_review')
      reload
      unless skip_campaign_plan_update
        campaign_plan.update_columns(
          approval_status: 'pending_approval',
          submitted_for_approval_at: Time.current
        )
        campaign_plan.reload
      end
      unless skip_audit_log
        PlanAuditLog.create!(
          campaign_plan: campaign_plan,
          plan_version: self,
          user: user,
          action: 'version_submitted_for_review',
          details: {
            version_number: version_number,
            submitted_at: Time.current
          }
        )
      end
    end
  end

  def create_snapshot_from_plan!
    update!(
      content: {
        generated_summary: campaign_plan.generated_summary,
        generated_strategy: campaign_plan.generated_strategy,
        generated_timeline: campaign_plan.generated_timeline,
        generated_assets: campaign_plan.generated_assets,
        content_strategy: campaign_plan.content_strategy,
        creative_approach: campaign_plan.creative_approach,
        strategic_rationale: campaign_plan.strategic_rationale,
        content_mapping: campaign_plan.content_mapping
      },
      metadata: {
        campaign_type: campaign_plan.campaign_type,
        objective: campaign_plan.objective,
        target_audience: campaign_plan.target_audience,
        budget_constraints: campaign_plan.budget_constraints,
        timeline_constraints: campaign_plan.timeline_constraints,
        snapshot_created_at: Time.current
      }
    )
  end

  private

  def set_version_number
    self.version_number ||= next_version_number
  end

  def set_as_current_version
    transaction do
      # Set all other versions as not current
      campaign_plan.plan_versions.where.not(id: id).update_all(is_current: false)
      # Set this version as current
      update_column(:is_current, true)
      # Update campaign plan's current version
      campaign_plan.update_column(:current_version_id, id)
    end
  end

  def update_campaign_plan_current_version
    if is_current?
      campaign_plan.update_column(:current_version_id, id)
    end
  end
end