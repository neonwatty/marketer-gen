require "test_helper"

class JourneyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def setup
    # Create test data manually
    @campaign = Campaign.create!(
      name: "Test Campaign",
      status: "draft",
      purpose: "Testing purposes"
    )
  end

  def teardown
    # Clean up test data
    Campaign.destroy_all
    Journey.destroy_all
    JourneyStage.destroy_all
  end

  test "should create journey with valid attributes" do
    journey = Journey.new(
      name: "Test Journey",
      campaign: @campaign,
      template_type: "lead_nurturing",
      purpose: "Test purpose"
    )
    
    assert journey.valid?
    assert journey.save
  end

  test "should require name" do
    journey = Journey.new
    assert_not journey.valid?
    assert_includes journey.errors[:name], "can't be blank"
  end

  test "should validate template type" do
    journey = Journey.new(
      name: "Test Journey",
      campaign: @campaign,
      template_type: "invalid_type"
    )
    
    assert_not journey.valid?
    assert_includes journey.errors[:template_type], "is not included in the list"
  end

  test "should add stages correctly" do
    journey = Journey.create!(
      name: "Test Journey",
      campaign: @campaign,
      template_type: "lead_nurturing"
    )
    
    stage = journey.add_stage(
      name: "Test Stage",
      stage_type: "Awareness",
      description: "Test description"
    )
    
    assert stage.persisted?
    assert_equal 1, journey.stage_count
    assert_equal 0, stage.position
  end

  test "should calculate completion percentage" do
    journey = Journey.create!(
      name: "Test Journey",
      campaign: @campaign,
      template_type: "lead_nurturing"
    )
    
    # Add stages
    stage1 = journey.add_stage(name: "Stage 1", stage_type: "Awareness")
    stage2 = journey.add_stage(name: "Stage 2", stage_type: "Consideration")
    
    # Initially 0% completion
    assert_equal 0.0, journey.completion_percentage
    
    # Complete one stage
    stage1.update!(status: 'completed')
    assert_equal 50.0, journey.completion_percentage
    
    # Complete both stages  
    stage2.update!(status: 'published')
    assert_equal 100.0, journey.completion_percentage
  end
end
