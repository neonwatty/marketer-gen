require "test_helper"

class DebugCollaborationTest < ActiveSupport::TestCase
  def setup
    @marketer = users(:marketer_user)
    @team_member = users(:team_member_user)
    @admin = users(:admin_user)
  end

  test "debug submission workflow" do
    # Create a plan with proper content
    plan = CampaignPlan.create!(
      user: @marketer,
      name: "Debug Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      status: "completed", # Make sure it's completed
      generated_summary: "Test summary for collaboration",
      generated_strategy: { phases: ["Research", "Launch"] }
    )
    
    puts "Plan created: #{plan.persisted?}"
    puts "Plan status: #{plan.status}"
    puts "Plan has content: #{plan.has_generated_content?}"
    puts "Plan completed: #{plan.completed?}"
    puts "Plan approval status: #{plan.approval_status}"
    puts "Can submit for approval: #{plan.can_be_submitted_for_approval?}"
    
    # Try to submit for approval
    result = plan.submit_for_approval!(@marketer)
    puts "Submit result: #{result}"
    
    plan.reload
    puts "After submit - approval status: #{plan.approval_status}"
    puts "Current version exists: #{plan.current_version.present?}"
    puts "Version count: #{plan.plan_versions.count}"
    
    assert result, "Submission should succeed"
    assert_equal "pending_approval", plan.approval_status
  end

  test "debug version creation" do
    plan = campaign_plans(:completed_plan)
    puts "Plan status: #{plan.status}"
    puts "Has content: #{plan.has_generated_content?}"
    puts "Completed: #{plan.completed?}"
    puts "Can submit: #{plan.can_be_submitted_for_approval?}"
    
    # Try to create version directly
    version = plan.create_version!(@marketer, "Test version")
    puts "Version created: #{version.persisted?}"
    puts "Version number: #{version.version_number}"
    puts "Is current: #{version.is_current?}"
    
    assert version.persisted?
    assert_equal 1, version.version_number
  end
end