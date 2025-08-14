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
end
