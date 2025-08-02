class PlanRevision < ApplicationRecord
  belongs_to :campaign_plan
  belongs_to :user

  validates :revision_number, presence: true, numericality: { greater_than: 0 }
  validates :plan_data, presence: true
  validates :change_summary, presence: true

  # JSON serialization for plan data
  serialize :plan_data, coder: JSON
  serialize :changes_made, coder: JSON
  serialize :metadata, coder: JSON

  scope :latest_first, -> { order(revision_number: :desc) }
  scope :oldest_first, -> { order(revision_number: :asc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :major_revisions, -> { where("revision_number % 1 = 0") }
  scope :minor_revisions, -> { where("revision_number % 1 != 0") }

  before_validation :set_defaults, on: :create

  def self.compare_revisions(revision_1, revision_2)
    return {} if revision_1.nil? || revision_2.nil?

    changes = {}
    data_1 = revision_1.plan_data || {}
    data_2 = revision_2.plan_data || {}

    # Find all keys from both revisions
    all_keys = (data_1.keys + data_2.keys).uniq

    all_keys.each do |key|
      value_1 = data_1[key]
      value_2 = data_2[key]

      if value_1 != value_2
        changes[key] = {
          from: value_1,
          to: value_2,
          changed_at: revision_2.created_at
        }
      end
    end

    {
      revision_from: revision_1.revision_number,
      revision_to: revision_2.revision_number,
      changes: changes,
      change_count: changes.length,
      compared_at: Time.current
    }
  end

  def compare_with(other_revision)
    self.class.compare_revisions(self, other_revision)
  end

  def major_revision?
    revision_number % 1 == 0
  end

  def minor_revision?
    !major_revision?
  end

  def next_major_version
    revision_number.floor + 1.0
  end

  def next_minor_version
    (revision_number + 0.1).round(1)
  end

  def previous_revision
    campaign_plan.plan_revisions
                 .where("revision_number < ?", revision_number)
                 .order(revision_number: :desc)
                 .first
  end

  def next_revision
    campaign_plan.plan_revisions
                 .where("revision_number > ?", revision_number)
                 .order(revision_number: :asc)
                 .first
  end

  def changes_from_previous
    prev_revision = previous_revision
    return {} unless prev_revision

    prev_revision.compare_with(self)
  end

  def revert_to!
    campaign_plan.update!(
      strategic_rationale: plan_data["strategic_rationale"],
      target_audience: plan_data["target_audience"],
      messaging_framework: plan_data["messaging_framework"],
      channel_strategy: plan_data["channel_strategy"],
      timeline_phases: plan_data["timeline_phases"],
      success_metrics: plan_data["success_metrics"],
      budget_allocation: plan_data["budget_allocation"],
      creative_approach: plan_data["creative_approach"],
      market_analysis: plan_data["market_analysis"],
      version: revision_number
    )

    # Create a new revision for this revert action
    campaign_plan.plan_revisions.create!(
      revision_number: campaign_plan.next_version,
      plan_data: plan_data,
      user: Current.user,
      change_summary: "Reverted to version #{revision_number}",
      metadata: { reverted_from: campaign_plan.version, reverted_to: revision_number }
    )
  end

  def summary_of_changes
    changes = changes_from_previous
    return "Initial revision" if changes.empty?

    change_types = []

    changes[:changes].each do |field, change_data|
      case field
      when "strategic_rationale"
        change_types << "strategic approach"
      when "target_audience"
        change_types << "audience targeting"
      when "messaging_framework"
        change_types << "messaging"
      when "channel_strategy"
        change_types << "channel mix"
      when "timeline_phases"
        change_types << "timeline"
      when "budget_allocation"
        change_types << "budget"
      when "success_metrics"
        change_types << "success metrics"
      else
        change_types << field.humanize.downcase
      end
    end

    "Updated #{change_types.join(', ')}"
  end

  def data_snapshot
    {
      revision_number: revision_number,
      created_at: created_at,
      user: user.display_name,
      change_summary: change_summary,
      plan_data: plan_data,
      changes_made: changes_made,
      metadata: metadata
    }
  end

  private

  def set_defaults
    self.metadata ||= {}
    self.changes_made ||= {}
  end
end
