class CampaignPlanRevisionTracker
  def initialize(campaign)
    @campaign = campaign
  end

  def save_revision(plan_data, user, change_summary = nil)
    campaign_plan = @campaign.campaign_plans.first

    # Create a campaign plan if none exists
    unless campaign_plan
      campaign_plan = @campaign.campaign_plans.create!(
        name: "#{@campaign.name} Plan",
        user: user,
        strategic_rationale: plan_data[:strategic_rationale] || { "rationale" => "Strategic rationale to be developed" },
        target_audience: plan_data[:target_audience] || { "audience" => "Target audience to be defined" },
        messaging_framework: plan_data[:messaging_framework] || { "framework" => "Messaging framework to be created" },
        channel_strategy: plan_data[:channel_strategy] || [ "email", "social_media" ],
        timeline_phases: plan_data[:timeline_phases] || [ { "phase" => "Planning", "duration" => 4 } ],
        success_metrics: plan_data[:success_metrics] || { "leads" => 100, "awareness" => 10 }
      )
    end

    latest_revision = campaign_plan.plan_revisions.order(:revision_number).last
    new_version = latest_revision ? latest_revision.next_minor_version : 1.0

    revision = campaign_plan.plan_revisions.create!(
      revision_number: new_version,
      plan_data: plan_data,
      user: user,
      change_summary: change_summary || "Plan updated",
      changes_made: calculate_changes(latest_revision&.plan_data, plan_data)
    )

    { success: true, revision: revision, version: new_version }
  end

  def get_revision_history
    campaign_plan = @campaign.campaign_plans.first
    return [] unless campaign_plan

    campaign_plan.plan_revisions.latest_first.map do |revision|
      {
        version: revision.revision_number,
        user: revision.user.display_name,
        created_at: revision.created_at,
        change_summary: revision.change_summary,
        changes_count: revision.changes_made&.keys&.length || 0
      }
    end
  end

  def get_latest_revision
    campaign_plan = @campaign.campaign_plans.first
    return nil unless campaign_plan

    latest = campaign_plan.plan_revisions.latest_first.first
    return nil unless latest

    {
      version: latest.revision_number,
      strategic_rationale: latest.plan_data&.dig("strategic_rationale"),
      target_audience: latest.plan_data&.dig("target_audience"),
      messaging_framework: latest.plan_data&.dig("messaging_framework"),
      user: latest.user.display_name,
      created_at: latest.created_at
    }
  end

  def compare_revisions(version_1, version_2)
    campaign_plan = @campaign.campaign_plans.first
    return { success: false, error: "No campaign plan found" } unless campaign_plan

    revision_1 = campaign_plan.plan_revisions.find_by(revision_number: version_1)
    revision_2 = campaign_plan.plan_revisions.find_by(revision_number: version_2)

    return { success: false, error: "Revision not found" } unless revision_1 && revision_2

    comparison = PlanRevision.compare_revisions(revision_1, revision_2)
    { success: true }.merge(comparison)
  end

  def rollback_to_revision(version, user)
    campaign_plan = @campaign.campaign_plans.first
    return { success: false, error: "No campaign plan found" } unless campaign_plan

    target_revision = campaign_plan.plan_revisions.find_by(revision_number: version)
    return { success: false, error: "Revision not found" } unless target_revision

    begin
      target_revision.revert_to!
      { success: true, message: "Successfully rolled back to version #{version}" }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def get_current_plan
    campaign_plan = @campaign.campaign_plans.first
    return nil unless campaign_plan

    {
      strategy: campaign_plan.strategic_rationale,
      audience: campaign_plan.target_audience,
      messaging: campaign_plan.messaging_framework,
      channels: campaign_plan.channel_strategy,
      timeline: campaign_plan.timeline_phases,
      metrics: campaign_plan.success_metrics,
      version: campaign_plan.version
    }
  end

  private

  def calculate_changes(old_data, new_data)
    return {} unless old_data && new_data

    changes = {}

    # Compare each key in the new data
    new_data.each do |key, new_value|
      old_value = old_data[key]

      if old_value != new_value
        changes[key] = {
          from: old_value,
          to: new_value,
          change_type: determine_change_type(old_value, new_value)
        }
      end
    end

    # Check for removed keys
    old_data.each do |key, old_value|
      unless new_data.key?(key)
        changes[key] = {
          from: old_value,
          to: nil,
          change_type: "removed"
        }
      end
    end

    changes
  end

  def determine_change_type(old_value, new_value)
    return "added" if old_value.nil? && !new_value.nil?
    return "removed" if !old_value.nil? && new_value.nil?
    return "modified" if old_value != new_value
    "unchanged"
  end
end
