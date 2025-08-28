require "test_helper"

class ProjectManagementServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @service = ProjectManagementService.new(@campaign_plan, @user)
    
    # Create some test milestones
    @pending_milestone = project_milestones(:design_phase)
    @in_progress_milestone = create_milestone(
      name: "Development Phase",
      status: "in_progress",
      priority: "high",
      milestone_type: "development",
      completion_percentage: 60,
      estimated_hours: 40,
      actual_hours: 25
    )
    @completed_milestone = create_milestone(
      name: "Planning Phase",
      status: "completed",
      priority: "medium",
      milestone_type: "planning",
      completion_percentage: 100
    )
    # Set completed_at after creation to avoid validation issues
    @completed_milestone.update_columns(completed_at: 1.week.ago, created_at: 2.weeks.ago)
    @overdue_milestone = create_milestone(
      name: "Overdue Task",
      status: "pending",
      priority: "critical",
      due_date: 2.days.from_now,
      milestone_type: "review"
    )
    # Set it to overdue after creation
    @overdue_milestone.update_columns(due_date: 2.days.ago, status: "overdue")
  end

  # Main service call tests
  test "should return success with comprehensive project data" do
    result = @service.call
    
    assert result[:success]
    assert_includes result[:data].keys, :project_status
    assert_includes result[:data].keys, :milestone_summary
    assert_includes result[:data].keys, :resource_allocation
    assert_includes result[:data].keys, :timeline_visualization
    assert_includes result[:data].keys, :risk_assessment
    assert_includes result[:data].keys, :team_workload
  end

  test "should handle errors gracefully in main call" do
    # Mock an error in project status calculation
    @service.stubs(:calculate_project_status).raises(StandardError.new("Test error"))
    
    result = @service.call
    
    assert_not result[:success]
    assert_includes result[:error], "Test error"
    assert_equal @campaign_plan.id, result[:context][:campaign_plan_id]
  end

  # Milestone creation tests
  test "should create milestone successfully" do
    milestone_params = {
      name: "New Test Milestone",
      description: "Test description",
      due_date: 2.weeks.from_now,
      priority: "high",
      milestone_type: "development",
      estimated_hours: 30
    }
    
    assert_difference 'ProjectMilestone.count', 1 do
      result = @service.create_milestone(milestone_params)
      assert result[:success]
      assert_equal "New Test Milestone", result[:data][:milestone].name
      assert_equal @user, result[:data][:milestone].created_by
    end
  end

  test "should fail to create milestone with invalid params" do
    milestone_params = {
      name: "", # Invalid - blank name
      due_date: 1.day.ago, # Invalid - past date
      priority: "invalid_priority" # Invalid priority
    }
    
    assert_no_difference 'ProjectMilestone.count' do
      result = @service.create_milestone(milestone_params)
      assert_not result[:success]
      assert_includes result[:error], "Failed to create milestone"
      assert result[:errors].any?
    end
  end

  # Milestone update tests
  test "should update milestone successfully" do
    update_params = {
      name: "Updated Milestone Name",
      priority: "critical",
      completion_percentage: 75
    }
    
    result = @service.update_milestone(@pending_milestone.id, update_params)
    
    assert result[:success]
    @pending_milestone.reload
    assert_equal "Updated Milestone Name", @pending_milestone.name
    assert_equal "critical", @pending_milestone.priority
    assert_equal 75, @pending_milestone.completion_percentage
  end

  test "should handle milestone not found in update" do
    result = @service.update_milestone(999999, { name: "Test" })
    
    assert_not result[:success]
    assert_equal "Milestone not found", result[:error]
  end

  test "should handle status change logic in update" do
    # Test status change from pending to in_progress
    result = @service.update_milestone(@pending_milestone.id, { status: "in_progress" })
    
    assert result[:success]
    @pending_milestone.reload
    assert_equal "in_progress", @pending_milestone.status
  end

  # Milestone completion tests
  test "should complete milestone successfully" do
    # Set up milestone that can be completed
    @in_progress_milestone.update!(completion_percentage: 100)
    
    result = @service.complete_milestone(@in_progress_milestone.id)
    
    assert result[:success]
    @in_progress_milestone.reload
    assert_equal "completed", @in_progress_milestone.status
    assert_not_nil @in_progress_milestone.completed_at
    assert_equal @user, @in_progress_milestone.completed_by
    assert result[:data][:next_milestones].is_a?(Array)
  end

  test "should fail to complete milestone that cannot be completed" do
    # Milestone not at 100% completion
    result = @service.complete_milestone(@in_progress_milestone.id)
    
    assert_not result[:success]
    assert_includes result[:error], "Cannot complete milestone"
  end

  test "should handle milestone not found in completion" do
    result = @service.complete_milestone(999999)
    
    assert_not result[:success]
    assert_equal "Milestone not found", result[:error]
  end

  # Resource assignment tests
  test "should assign resources successfully" do
    resource_allocation = [
      { "id" => "dev1", "type" => "developer", "name" => "John Developer", "cost" => 1000, "allocation_percentage" => 50 },
      { "id" => "des1", "type" => "designer", "name" => "Jane Designer", "cost" => 800, "allocation_percentage" => 100 }
    ]
    
    result = @service.assign_resources(@pending_milestone.id, resource_allocation)
    
    assert result[:success]
    @pending_milestone.reload
    
    resources = JSON.parse(@pending_milestone.resources_required)
    assert_equal 2, resources.count
    assert resources.any? { |r| r["type"] == "developer" }
    assert resources.any? { |r| r["type"] == "designer" }
  end

  test "should merge with existing resources" do
    # Set up milestone with existing resources
    existing_resources = [{ "id" => "existing", "type" => "manager", "cost" => 500 }]
    @pending_milestone.update!(resources_required: existing_resources.to_json)
    
    new_resources = [{ "id" => "new", "type" => "developer", "cost" => 1000 }]
    result = @service.assign_resources(@pending_milestone.id, new_resources)
    
    assert result[:success]
    @pending_milestone.reload
    
    resources = JSON.parse(@pending_milestone.resources_required)
    assert_equal 2, resources.count
    assert resources.any? { |r| r["type"] == "manager" }
    assert resources.any? { |r| r["type"] == "developer" }
  end

  # Gantt chart data tests
  test "should generate gantt chart data" do
    result = @service.generate_gantt_chart_data
    
    assert result[:success]
    assert result[:data][:gantt_data].is_a?(Array)
    assert result[:data][:project_timeline].is_a?(Hash)
    
    gantt_data = result[:data][:gantt_data]
    assert gantt_data.count >= 4 # Our test milestones
    
    # Check structure of gantt data
    first_milestone = gantt_data.first
    assert_includes first_milestone.keys, :id
    assert_includes first_milestone.keys, :name
    assert_includes first_milestone.keys, :status
    assert_includes first_milestone.keys, :progress
    assert_includes first_milestone.keys, :dependencies
  end

  # Team performance tests
  test "should calculate team performance" do
    # Assign milestones to users
    @pending_milestone.update!(assigned_to: @user)
    @in_progress_milestone.update!(assigned_to: @user)
    @completed_milestone.update!(assigned_to: users(:team_member_user), completed_by: users(:team_member_user))
    
    result = @service.calculate_team_performance
    
    assert result[:success]
    performance_data = result[:data][:team_performance]
    
    assert performance_data.is_a?(Array)
    assert performance_data.count >= 1
    
    # Check performance structure
    user_performance = performance_data.find { |p| p[:user] == @user }
    assert user_performance
    assert_includes user_performance.keys, :total_assigned
    assert_includes user_performance.keys, :completed
    assert_includes user_performance.keys, :efficiency_score
  end

  # Timeline sync tests
  test "should sync with campaign timeline when available" do
    # Create milestones that match timeline phases
    planning_milestone = create_milestone(
      name: "Planning Phase",
      milestone_type: "planning",
      due_date: 1.week.from_now
    )
    development_milestone = create_milestone(
      name: "Development Work",
      milestone_type: "development", 
      due_date: 4.weeks.from_now
    )
    
    # Mock campaign timeline data
    timeline_data = {
      "phases" => [
        {
          "name" => "planning",
          "due_date" => 2.weeks.from_now.to_s,
          "estimated_hours" => 40
        },
        {
          "name" => "development", 
          "due_date" => 6.weeks.from_now.to_s,
          "estimated_hours" => 120
        }
      ]
    }
    
    @campaign_plan.update!(generated_timeline: timeline_data.to_json)
    
    result = @service.sync_with_campaign_timeline
    
    assert result[:success], "Expected success but got: #{result[:error]}"
    assert result[:data][:sync_results].is_a?(Hash)
    assert_includes result[:data][:sync_results].keys, :updated_count
  end

  test "should fail sync when no campaign timeline available" do
    @campaign_plan.update!(generated_timeline: nil)
    
    result = @service.sync_with_campaign_timeline
    
    assert_not result[:success]
    assert_includes result[:error], "No campaign timeline available"
  end

  # Private method testing through public interface
  test "should calculate correct project status" do
    result = @service.call
    project_status = result[:data][:project_status]
    
    assert_includes project_status.keys, :status
    assert_includes project_status.keys, :progress
    assert_includes project_status.keys, :total_milestones
    assert_includes project_status.keys, :completed
    assert_includes project_status.keys, :in_progress
    assert_includes project_status.keys, :overdue
    
    # Verify counts match our test data
    assert project_status[:total_milestones] >= 4
    assert project_status[:completed] >= 1
    assert project_status[:overdue] >= 1
  end

  test "should generate milestone summary correctly" do
    result = @service.call
    milestone_summary = result[:data][:milestone_summary]
    
    assert_includes milestone_summary.keys, :by_status
    assert_includes milestone_summary.keys, :by_priority
    assert_includes milestone_summary.keys, :by_type
    assert_includes milestone_summary.keys, :overdue_critical
    assert_includes milestone_summary.keys, :due_this_week
    
    # Check that we have the expected status breakdown
    assert milestone_summary[:by_status]['pending'] >= 1
    assert milestone_summary[:by_status]['in_progress'] >= 1
    assert milestone_summary[:by_status]['completed'] >= 1
    assert milestone_summary[:by_status]['overdue'] >= 1
  end

  test "should calculate resource allocation correctly" do
    # Set up milestones with hours
    @pending_milestone.update!(estimated_hours: 20)
    @in_progress_milestone.update!(estimated_hours: 40, actual_hours: 25)
    @completed_milestone.update!(estimated_hours: 30, actual_hours: 28)
    
    result = @service.call
    resource_allocation = result[:data][:resource_allocation]
    
    assert_includes resource_allocation.keys, :total_estimated_hours
    assert_includes resource_allocation.keys, :total_actual_hours
    assert_includes resource_allocation.keys, :hour_variance
    
    assert resource_allocation[:total_estimated_hours] >= 90
    assert resource_allocation[:total_actual_hours] >= 50
  end

  test "should assess project risks correctly" do
    result = @service.call
    risk_assessment = result[:data][:risk_assessment]
    
    assert_includes risk_assessment.keys, :overall_risk_level
    assert_includes risk_assessment.keys, :risk_score
    assert_includes risk_assessment.keys, :risk_factors
    assert_includes risk_assessment.keys, :mitigation_suggestions
    
    # Should identify overdue milestones as a risk
    assert risk_assessment[:risk_factors][:overdue_milestones] >= 1
    assert risk_assessment[:mitigation_suggestions].any?
  end

  test "should calculate team workload when user provided" do
    # Assign milestones to create workload
    @pending_milestone.update!(assigned_to: @user, estimated_hours: 20)
    @in_progress_milestone.update!(assigned_to: @user, estimated_hours: 40)
    
    result = @service.call
    team_workload = result[:data][:team_workload]
    
    assert_includes team_workload.keys, :team_workload
    assert_includes team_workload.keys, :workload_balance
    
    # Should have workload data for assigned user
    user_workload = team_workload[:team_workload].find { |w| w[:user] == @user }
    assert user_workload
    assert user_workload[:estimated_hours] >= 60
  end

  # Edge cases and error handling
  test "should handle empty milestone list" do
    @campaign_plan.project_milestones.destroy_all
    
    result = @service.call
    
    assert result[:success]
    project_status = result[:data][:project_status]
    assert_equal 'not_started', project_status[:status]
    assert_equal 0, project_status[:progress]
  end

  test "should handle malformed JSON in milestone fields gracefully" do
    @pending_milestone.update_column(:dependencies, "invalid json")
    
    # Should not raise error
    result = @service.call
    assert result[:success]
  end

  test "should handle missing user gracefully" do
    service_without_user = ProjectManagementService.new(@campaign_plan, nil)
    
    result = service_without_user.call
    assert result[:success]
    
    # Team workload should be empty without user
    assert_equal({}, result[:data][:team_workload])
  end

  # Service logging tests
  test "should log service calls" do
    Rails.logger.expects(:info).with(includes("ProjectManagementService"))
    @service.call
  end

  test "should log milestone creation" do
    milestone_params = { name: "Test Log Milestone", due_date: 1.week.from_now, priority: "low", milestone_type: "planning" }
    
    # Use a more flexible approach to check that service logging occurs
    Rails.logger.expects(:info).with(anything).at_least_once
    Rails.logger.expects(:info).with(includes("Service Call: create_milestone")).once
    
    result = @service.create_milestone(milestone_params)
    assert result[:success]
  end

  test "should log milestone updates" do
    # Use a more flexible approach to check that service logging occurs
    Rails.logger.expects(:info).with(anything).at_least_once
    Rails.logger.expects(:info).with(includes("Service Call: update_milestone")).once
    
    result = @service.update_milestone(@pending_milestone.id, { name: "Updated Name" })
    assert result[:success]
  end

  # Helper method tests
  test "should parse JSON fields correctly" do
    # Test with proper dependency format
    valid_dependency_json = '[{"milestone_id": 123, "name": "Prerequisite", "completed": false}]'
    single_dependency_json = '{"milestone_id": 456, "name": "Single Dep", "completed": true}'
    invalid_format_json = '{"key": "value"}' # Valid JSON but wrong format for dependencies
    invalid_json = 'invalid json'
    nil_value = nil
    
    # Use public interface to test private method behavior
    milestone_with_valid_deps = create_milestone(dependencies: valid_dependency_json)
    milestone_with_single_dep = create_milestone(dependencies: single_dependency_json)
    milestone_with_invalid_format = create_milestone(dependencies: invalid_format_json)
    milestone_with_invalid_json = create_milestone(dependencies: invalid_json)
    milestone_with_nil = create_milestone(dependencies: nil_value)
    
    result = @service.generate_gantt_chart_data
    assert result[:success], "Expected gantt chart generation to succeed but got: #{result[:error]}"
    
    # The service should handle all cases without error
    gantt_data = result[:data][:gantt_data]
    assert gantt_data.is_a?(Array)
    
    # Find milestone data in gantt chart
    valid_milestone_data = gantt_data.find { |m| m[:id] == milestone_with_valid_deps.id }
    single_milestone_data = gantt_data.find { |m| m[:id] == milestone_with_single_dep.id }
    invalid_format_data = gantt_data.find { |m| m[:id] == milestone_with_invalid_format.id }
    invalid_milestone_data = gantt_data.find { |m| m[:id] == milestone_with_invalid_json.id }
    nil_milestone_data = gantt_data.find { |m| m[:id] == milestone_with_nil.id }
    
    # Verify parsing behavior
    assert valid_milestone_data[:dependencies].is_a?(Array) # Valid dependency array
    assert valid_milestone_data[:dependencies].length == 1
    assert_equal 123, valid_milestone_data[:dependencies][0]['milestone_id']
    
    assert single_milestone_data[:dependencies].is_a?(Array) # Single dependency wrapped in array
    assert single_milestone_data[:dependencies].length == 1
    assert_equal 456, single_milestone_data[:dependencies][0]['milestone_id']
    
    assert invalid_format_data[:dependencies] == [] # Invalid format returns empty array
    assert invalid_milestone_data[:dependencies] == [] # Invalid JSON returns empty array
    assert nil_milestone_data[:dependencies] == [] # Nil returns empty array
  end

  # Integration tests
  test "completing milestone should unlock dependent milestones" do
    # Create milestone with dependency
    dependent_milestone = create_milestone(
      name: "Dependent Task",
      status: "pending",
      dependencies: [
        { "milestone_id" => @in_progress_milestone.id, "name" => "Development Phase", "completed" => false, "required" => true }
      ].to_json
    )
    
    # Complete the blocking milestone
    @in_progress_milestone.update!(completion_percentage: 100)
    result = @service.complete_milestone(@in_progress_milestone.id)
    
    assert result[:success]
    
    # Check that dependent milestone's dependencies are updated
    dependent_milestone.reload
    dependencies = JSON.parse(dependent_milestone.dependencies)
    blocking_dep = dependencies.find { |d| d["milestone_id"] == @in_progress_milestone.id }
    assert blocking_dep["completed"]
  end

  test "should update campaign plan metadata on milestone completion" do
    @in_progress_milestone.update!(completion_percentage: 100)
    
    result = @service.complete_milestone(@in_progress_milestone.id)
    
    assert result[:success]
    @campaign_plan.reload
    
    # Check that campaign metadata includes project progress
    metadata = @campaign_plan.metadata || {}
    assert_includes metadata.keys, "project_progress"
    assert_includes metadata.keys, "project_status"
    assert_kind_of Numeric, metadata["project_progress"]
    assert_kind_of String, metadata["project_status"]
  end

  private

  def create_milestone(attributes = {})
    default_attributes = {
      campaign_plan: @campaign_plan,
      created_by: @user,
      name: "Test Milestone",
      due_date: 2.weeks.from_now,
      status: "pending", 
      priority: "medium",
      milestone_type: "development",
      completion_percentage: 0
    }
    
    milestone = ProjectMilestone.create!(default_attributes.merge(attributes))
    milestone
  end
end