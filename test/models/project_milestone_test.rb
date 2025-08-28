require "test_helper"

class ProjectMilestoneTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @milestone = project_milestones(:design_phase)
  end

  # Validation tests
  test "should be valid with valid attributes" do
    milestone = ProjectMilestone.new(
      campaign_plan: @campaign_plan,
      created_by: @user,
      name: "Test Milestone",
      description: "Test description",
      due_date: 1.week.from_now,
      status: "pending",
      priority: "medium",
      milestone_type: "development",
      completion_percentage: 0
    )
    assert milestone.valid?
  end

  test "should require name" do
    milestone = build_milestone(name: nil)
    assert_not milestone.valid?
    assert_includes milestone.errors[:name], "can't be blank"
  end

  test "should require name not exceed 255 characters" do
    milestone = build_milestone(name: "a" * 256)
    assert_not milestone.valid?
    assert_includes milestone.errors[:name], "is too long (maximum is 255 characters)"
  end

  test "should require description not exceed 2000 characters" do
    milestone = build_milestone(description: "a" * 2001)
    assert_not milestone.valid?
    assert_includes milestone.errors[:description], "is too long (maximum is 2000 characters)"
  end

  test "should require valid status" do
    milestone = build_milestone(status: "invalid_status")
    assert_not milestone.valid?
    assert_includes milestone.errors[:status], "is not included in the list"
  end

  test "should require valid priority" do
    milestone = build_milestone(priority: "invalid_priority")
    assert_not milestone.valid?
    assert_includes milestone.errors[:priority], "is not included in the list"
  end

  test "should require valid milestone type" do
    milestone = build_milestone(milestone_type: "invalid_type")
    assert_not milestone.valid?
    assert_includes milestone.errors[:milestone_type], "is not included in the list"
  end

  test "should require due date" do
    milestone = build_milestone(due_date: nil)
    assert_not milestone.valid?
    assert_includes milestone.errors[:due_date], "can't be blank"
  end

  test "should not allow due date in past on create" do
    milestone = build_milestone(due_date: 1.day.ago)
    assert_not milestone.valid?
    assert_includes milestone.errors[:due_date], "cannot be in the past"
  end

  test "should allow due date in past on update" do
    @milestone.update(due_date: 1.day.ago)
    assert @milestone.valid?
  end

  test "should validate estimated hours range" do
    milestone = build_milestone(estimated_hours: -1)
    assert_not milestone.valid?
    assert_includes milestone.errors[:estimated_hours], "must be greater than or equal to 0"

    milestone = build_milestone(estimated_hours: 1001)
    assert_not milestone.valid?
    assert_includes milestone.errors[:estimated_hours], "must be less than or equal to 1000"
  end

  test "should validate actual hours non-negative" do
    milestone = build_milestone(actual_hours: -1)
    assert_not milestone.valid?
    assert_includes milestone.errors[:actual_hours], "must be greater than or equal to 0"
  end

  test "should validate completion percentage range" do
    milestone = build_milestone(completion_percentage: -1)
    assert_not milestone.valid?
    assert_includes milestone.errors[:completion_percentage], "must be greater than or equal to 0"

    milestone = build_milestone(completion_percentage: 101)
    assert_not milestone.valid?
    assert_includes milestone.errors[:completion_percentage], "must be less than or equal to 100"
  end

  test "should validate completion date after creation" do
    milestone = build_milestone
    milestone.save!
    milestone.completed_at = milestone.created_at - 1.hour
    assert_not milestone.valid?
    assert_includes milestone.errors[:completed_at], "cannot be before creation date"
  end

  test "should validate assigned user exists" do
    milestone = build_milestone(assigned_to_id: 999999)
    assert_not milestone.valid?
    assert_includes milestone.errors[:assigned_to], "must be a valid user"
  end

  # Association tests
  test "should belong to campaign plan" do
    assert_respond_to @milestone, :campaign_plan
    assert_instance_of CampaignPlan, @milestone.campaign_plan
  end

  test "should belong to created by user" do
    assert_respond_to @milestone, :created_by
    assert_instance_of User, @milestone.created_by
  end

  test "should belong to assigned to user optionally" do
    assert_respond_to @milestone, :assigned_to
    @milestone.assigned_to = nil
    assert @milestone.valid?
  end

  test "should belong to completed by user optionally" do
    assert_respond_to @milestone, :completed_by
    @milestone.completed_by = nil
    assert @milestone.valid?
  end

  # Scope tests
  test "by_status scope should filter correctly" do
    pending_milestones = ProjectMilestone.by_status('pending')
    assert_equal ProjectMilestone.where(status: 'pending').count, pending_milestones.count
  end

  test "by_priority scope should filter correctly" do
    high_priority = ProjectMilestone.by_priority('high')
    assert_equal ProjectMilestone.where(priority: 'high').count, high_priority.count
  end

  test "pending scope should return pending milestones" do
    pending_count = ProjectMilestone.pending.count
    assert_equal ProjectMilestone.where(status: 'pending').count, pending_count
  end

  test "completed scope should return completed milestones" do
    completed_count = ProjectMilestone.completed.count
    assert_equal ProjectMilestone.where(status: 'completed').count, completed_count
  end

  test "overdue_items scope should return overdue milestones" do
    # Create an overdue milestone
    overdue_milestone = create_milestone(
      due_date: 2.days.from_now,
      status: 'in_progress'
    )
    # Manually set due date to past to simulate overdue condition
    overdue_milestone.update_column(:due_date, 1.day.ago)
    
    overdue_items = ProjectMilestone.overdue_items
    assert_includes overdue_items, overdue_milestone
  end

  test "due_soon scope should return milestones due within a week" do
    soon_milestone = create_milestone(due_date: 3.days.from_now)
    due_soon = ProjectMilestone.due_soon
    assert_includes due_soon, soon_milestone
  end

  test "high_priority scope should return high and critical priority milestones" do
    high_milestone = create_milestone(priority: 'high')
    critical_milestone = create_milestone(priority: 'critical')
    
    high_priority = ProjectMilestone.high_priority
    assert_includes high_priority, high_milestone
    assert_includes high_priority, critical_milestone
  end

  # Status helper method tests
  test "should correctly identify pending status" do
    milestone = create_milestone(status: 'pending')
    assert milestone.pending?
    assert_not milestone.in_progress?
    assert_not milestone.completed?
  end

  test "should correctly identify in_progress status" do
    milestone = create_milestone(status: 'in_progress')
    assert milestone.in_progress?
    assert_not milestone.pending?
    assert_not milestone.completed?
  end

  test "should correctly identify completed status" do
    milestone = create_milestone(status: 'completed')
    assert milestone.completed?
    assert_not milestone.pending?
    assert_not milestone.in_progress?
  end

  test "should correctly identify overdue status" do
    milestone = create_milestone(status: 'overdue')
    assert milestone.overdue?

    # Also test logic-based overdue detection
    overdue_milestone = create_milestone(
      due_date: 2.days.from_now,
      status: 'in_progress'
    )
    # Manually set due date to past to simulate overdue condition
    overdue_milestone.update_column(:due_date, 1.day.ago)
    assert overdue_milestone.overdue?
  end

  test "should correctly identify cancelled status" do
    milestone = create_milestone(status: 'cancelled')
    assert milestone.cancelled?
  end

  test "should correctly identify high priority" do
    high_milestone = create_milestone(priority: 'high')
    critical_milestone = create_milestone(priority: 'critical')
    medium_milestone = create_milestone(priority: 'medium')
    
    assert high_milestone.high_priority?
    assert critical_milestone.high_priority?
    assert_not medium_milestone.high_priority?
  end

  # Business logic tests
  test "can_be_started should return true for pending milestones with met dependencies" do
    milestone = create_milestone(status: 'pending', dependencies: [].to_json)
    assert milestone.can_be_started?
  end

  test "can_be_started should return false for non-pending milestones" do
    milestone = create_milestone(status: 'in_progress')
    assert_not milestone.can_be_started?
  end

  test "can_be_completed should return true for in_progress milestones at 100%" do
    milestone = create_milestone(status: 'in_progress', completion_percentage: 100)
    assert milestone.can_be_completed?
  end

  test "can_be_completed should return false for milestones not at 100%" do
    milestone = create_milestone(status: 'in_progress', completion_percentage: 80)
    assert_not milestone.can_be_completed?
  end

  test "start! should update status and timestamps" do
    milestone = create_milestone(status: 'pending')
    user = users(:team_member_user)
    
    assert milestone.start!(user)
    milestone.reload
    
    assert_equal 'in_progress', milestone.status
    assert_not_nil milestone.started_at
    assert_equal user, milestone.assigned_to
  end

  test "start! should fail if milestone cannot be started" do
    milestone = create_milestone(status: 'completed')
    user = users(:team_member_user)
    
    assert_not milestone.start!(user)
  end

  test "complete! should update status and timestamps" do
    milestone = create_milestone(status: 'in_progress', completion_percentage: 100)
    user = users(:team_member_user)
    
    assert milestone.complete!(user)
    milestone.reload
    
    assert_equal 'completed', milestone.status
    assert_not_nil milestone.completed_at
    assert_equal user, milestone.completed_by
  end

  test "complete! should fail if milestone cannot be completed" do
    milestone = create_milestone(status: 'in_progress', completion_percentage: 50)
    user = users(:team_member_user)
    
    assert_not milestone.complete!(user)
  end

  test "cancel! should update status and add reason to notes" do
    milestone = create_milestone(status: 'pending')
    reason = "Project scope changed"
    
    assert milestone.cancel!(reason)
    milestone.reload
    
    assert_equal 'cancelled', milestone.status
    assert_equal 0, milestone.completion_percentage
    assert_includes milestone.notes, reason
  end

  test "cancel! should fail for completed milestones" do
    milestone = create_milestone(status: 'completed')
    
    assert_not milestone.cancel!("Too late")
  end

  test "days_until_due should calculate correctly" do
    future_milestone = create_milestone(due_date: 5.days.from_now)
    assert_equal 5, future_milestone.days_until_due
    
    past_milestone = create_milestone(due_date: 5.days.from_now)
    past_milestone.update_column(:due_date, 3.days.ago)
    assert_equal(-3, past_milestone.days_until_due)
    
    completed_milestone = create_milestone(status: 'completed', due_date: 2.days.from_now)
    assert_equal 0, completed_milestone.days_until_due
  end

  test "duration_days should calculate work duration" do
    milestone = create_milestone(
      started_at: 5.days.ago,
      completed_at: 2.days.ago
    )
    # The ceil method might round up, so we check for range
    duration = milestone.duration_days
    assert duration >= 3 && duration <= 4, "Expected duration between 3 and 4 days, got #{duration}"
  end

  test "duration_days should return 0 if not completed" do
    milestone = create_milestone(started_at: 3.days.ago)
    assert_equal 0, milestone.duration_days
  end

  # JSON field parsing tests
  test "resource_allocation_summary should parse resources correctly" do
    resources = [
      { "type" => "developer", "cost" => 1000 },
      { "type" => "designer", "cost" => 800 },
      { "type" => "developer", "cost" => 1200 }
    ]
    
    milestone = create_milestone(resources_required: resources.to_json)
    summary = milestone.resource_allocation_summary
    
    assert_equal 3, summary[:total_resources]
    assert_includes summary[:resource_types], "developer"
    assert_includes summary[:resource_types], "designer"
    assert_equal 3000.0, summary[:estimated_cost]
  end

  test "deliverable_summary should parse deliverables correctly" do
    deliverables = [
      { "name" => "Design mockups", "completed" => true },
      { "name" => "Code review", "completed" => false },
      { "name" => "Documentation", "completed" => true }
    ]
    
    milestone = create_milestone(deliverables: deliverables.to_json)
    summary = milestone.deliverable_summary
    
    assert_equal 3, summary[:total_deliverables]
    assert_equal 2, summary[:completed_deliverables]
    assert_equal 1, summary[:pending_deliverables]
  end

  test "dependency_status should parse dependencies correctly" do
    dependencies = [
      { "name" => "API setup", "completed" => true, "required" => true },
      { "name" => "Database schema", "completed" => false, "required" => true }
    ]
    
    milestone = create_milestone(dependencies: dependencies.to_json)
    status = milestone.dependency_status
    
    assert_not status[:met]
    assert_equal 2, status[:total]
    assert_equal 1, status[:completed]
    assert_includes status[:blocking], "Database schema"
  end

  test "risk_assessment should parse risk factors correctly" do
    risks = [
      { "name" => "Technical complexity", "level" => "high" },
      { "name" => "Resource availability", "level" => "medium" },
      { "name" => "Timeline pressure", "level" => "critical" }
    ]
    
    milestone = create_milestone(risk_factors: risks.to_json)
    assessment = milestone.risk_assessment
    
    assert_equal "critical", assessment[:level]
    assert_equal 3, assessment[:total_risks]
    assert_equal 2, assessment[:high_priority_risks]
  end

  test "project_analytics should return comprehensive data" do
    milestone = create_milestone(
      name: "Test Milestone",
      status: "in_progress",
      priority: "high",
      milestone_type: "development",
      completion_percentage: 75,
      due_date: 3.days.from_now,
      estimated_hours: 40,
      actual_hours: 30
    )
    
    analytics = milestone.project_analytics
    
    assert_equal milestone.id, analytics[:milestone_id]
    assert_equal "Test Milestone", analytics[:name]
    assert_equal "in_progress", analytics[:status]
    assert_equal "high", analytics[:priority]
    assert_equal "development", analytics[:type]
    assert_equal 75, analytics[:progress]
    assert_equal 3, analytics[:days_until_due]
    assert_not analytics[:overdue]
    assert_equal 40, analytics[:estimated_hours]
    assert_equal 30, analytics[:actual_hours]
  end

  # Callback tests
  test "should set default completion percentage on create" do
    milestone = build_milestone(completion_percentage: nil)
    milestone.save!
    assert_equal 0, milestone.completion_percentage
  end

  test "should calculate overdue status automatically" do
    milestone = create_milestone(
      due_date: 2.days.from_now,
      status: 'in_progress'
    )
    
    # Manually set due date to past to simulate overdue condition
    milestone.update_column(:due_date, 1.day.ago)
    milestone.valid? # Trigger validations
    assert_equal 'overdue', milestone.status
  end

  test "should track completion metrics on status change" do
    milestone = create_milestone(status: 'in_progress')
    
    # Mock the campaign plan touch
    @campaign_plan.expects(:touch).with(:updated_at)
    
    milestone.update!(status: 'completed')
  end

  test "should create activity log on create and update" do
    # Test creation log - first for the build/save process
    Rails.logger.expects(:info).with(includes("ProjectMilestone")).at_least_once
    milestone = create_milestone(name: "New Milestone")
    
    # Test update log
    Rails.logger.expects(:info).with(includes("ProjectMilestone")).at_least_once
    milestone.update!(status: 'completed')
  end

  # Edge cases and error handling
  test "should handle invalid JSON in serialized fields gracefully" do
    milestone = create_milestone
    milestone.update_column(:dependencies, "invalid json")
    
    assert_equal({ met: true, blocking: [] }, milestone.dependency_status)
  end

  test "should handle nil serialized fields gracefully" do
    milestone = create_milestone(
      resources_required: nil,
      deliverables: nil,
      dependencies: nil,
      risk_factors: nil
    )
    
    assert_equal({}, milestone.resource_allocation_summary)
    assert_equal({}, milestone.deliverable_summary)
    assert_equal({ met: true, blocking: [] }, milestone.dependency_status)
    assert_equal({ level: 'low', factors: [] }, milestone.risk_assessment)
  end

  private

  def build_milestone(attributes = {})
    default_attributes = {
      campaign_plan: @campaign_plan,
      created_by: @user,
      name: "Test Milestone",
      due_date: 1.week.from_now,
      status: "pending",
      priority: "medium",
      milestone_type: "development",
      completion_percentage: 0
    }
    
    ProjectMilestone.new(default_attributes.merge(attributes))
  end

  def create_milestone(attributes = {})
    milestone = build_milestone(attributes)
    milestone.save!
    milestone
  end
end