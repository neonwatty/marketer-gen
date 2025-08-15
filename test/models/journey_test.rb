require "test_helper"

class JourneyTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
  end

  test "should belong to user" do
    assert_equal @user, @journey.user
  end

  test "should have many journey steps" do
    assert_respond_to @journey, :journey_steps
    assert @journey.journey_steps.count > 0
  end

  test "should validate presence of name" do
    journey = Journey.new
    journey.valid?
    assert_includes journey.errors[:name], "can't be blank"
  end

  test "should validate presence of campaign_type" do
    journey = Journey.new
    journey.valid?
    assert_includes journey.errors[:campaign_type], "can't be blank"
  end

  test "should validate campaign_type inclusion" do
    journey = Journey.new(campaign_type: "invalid_type")
    journey.valid?
    assert_includes journey.errors[:campaign_type], "is not included in the list"
  end

  test "should validate status inclusion" do
    journey = Journey.new(status: "invalid_status")
    journey.valid?
    assert_includes journey.errors[:status], "is not included in the list"
  end

  test "should validate name uniqueness within user scope" do
    existing_journey = @journey
    new_journey = @user.journeys.build(
      name: existing_journey.name,
      campaign_type: "conversion"
    )
    new_journey.valid?
    assert_includes new_journey.errors[:name], "already exists for this user"
  end

  test "should set default status to draft" do
    journey = @user.journeys.create!(
      name: "Test Journey",
      campaign_type: "awareness"
    )
    assert_equal "draft", journey.status
  end

  test "should set default stages based on campaign type" do
    journey = @user.journeys.create!(
      name: "Test Journey",
      campaign_type: "awareness"
    )
    assert_equal ["discovery", "education", "engagement"], journey.stages
  end

  test "should respond to active?" do
    assert_respond_to @journey, :active?
  end

  test "should respond to draft?" do
    assert_respond_to @journey, :draft?
  end

  test "should return total steps count" do
    assert_equal @journey.journey_steps.count, @journey.total_steps
  end

  test "should return ordered steps" do
    steps = @journey.ordered_steps
    assert_equal @journey.journey_steps.order(:sequence_order), steps
  end

  test "should calculate completion rate correctly" do
    # Create test steps with different statuses
    @journey.journey_steps.destroy_all
    @journey.journey_steps.create!(title: "Step 1", step_type: "email", sequence_order: 0, status: "completed")
    @journey.journey_steps.create!(title: "Step 2", step_type: "email", sequence_order: 1, status: "completed")
    @journey.journey_steps.create!(title: "Step 3", step_type: "email", sequence_order: 2, status: "active")
    @journey.journey_steps.create!(title: "Step 4", step_type: "email", sequence_order: 3, status: "draft")
    
    # 2 completed out of 4 total = 50%
    assert_equal 50.0, @journey.completion_rate
  end

  test "should return zero completion rate when no steps" do
    @journey.journey_steps.destroy_all
    assert_equal 0, @journey.completion_rate
  end

  test "should return last activity time" do
    # Clear existing steps and create new one
    @journey.journey_steps.destroy_all
    step = @journey.journey_steps.create!(title: "Test Step", step_type: "email", sequence_order: 0, status: "active")
    
    # Update the step to set updated_at
    step.update!(title: "Updated Test Step")
    
    # last_activity should be the max updated_at of journey_steps or journey updated_at
    expected_time = [step.updated_at, @journey.updated_at].max
    assert_in_delta expected_time.to_f, @journey.last_activity.to_f, 1.0
  end

  test "should calculate duration since creation" do
    # Mock the creation time to be 5 days ago
    creation_time = 5.days.ago
    @journey.update_column(:created_at, creation_time)
    
    expected_duration = ((Time.current - creation_time) / 1.day).round(1)
    assert_in_delta expected_duration, @journey.duration_since_creation, 0.1
  end

  test "should indicate journey can be duplicated" do
    assert @journey.can_be_duplicated?
  end

  test "should indicate when journey can be archived" do
    # Draft and completed statuses can be archived
    @journey.update!(status: 'draft')
    assert @journey.can_be_archived?
    
    @journey.update!(status: 'completed')
    assert @journey.can_be_archived?
    
    # Active status cannot be archived
    @journey.update!(status: 'active')
    assert_not @journey.can_be_archived?
  end

  test "should return analytics summary hash" do
    summary = @journey.analytics_summary
    
    assert_instance_of Hash, summary
    assert_includes summary, :total_steps
    assert_includes summary, :completion_rate
    assert_includes summary, :last_activity
    assert_includes summary, :duration
    assert_includes summary, :status
    assert_includes summary, :campaign_type
    assert_includes summary, :template_type
    
    assert_equal @journey.total_steps, summary[:total_steps]
    assert_equal @journey.completion_rate, summary[:completion_rate]
    assert_equal @journey.status, summary[:status]
    assert_equal @journey.campaign_type, summary[:campaign_type]
  end
end
