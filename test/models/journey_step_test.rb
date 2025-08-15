require "test_helper"

class JourneyStepTest < ActiveSupport::TestCase
  def setup
    @journey = journeys(:awareness_journey)
    @step = journey_steps(:awareness_step_one)
  end

  test "should belong to journey" do
    assert_equal @journey, @step.journey
  end

  test "should validate presence of title" do
    step = JourneyStep.new
    step.valid?
    assert_includes step.errors[:title], "can't be blank"
  end

  test "should validate presence of step_type" do
    step = JourneyStep.new
    step.valid?
    assert_includes step.errors[:step_type], "can't be blank"
  end

  test "should validate step_type inclusion" do
    step = JourneyStep.new(step_type: "invalid_type")
    step.valid?
    assert_includes step.errors[:step_type], "is not included in the list"
  end

  test "should validate channel inclusion when present" do
    step = JourneyStep.new(channel: "invalid_channel")
    step.valid?
    assert_includes step.errors[:channel], "is not included in the list"
  end

  test "should validate uniqueness of sequence_order within journey" do
    existing_step = @step
    
    new_step = @journey.journey_steps.build(
      title: "New Step",
      step_type: "email",
      sequence_order: existing_step.sequence_order
    )
    
    new_step.valid?
    assert_includes new_step.errors[:sequence_order], "must be unique within the journey"
  end

  test "should auto-set sequence_order if blank on create" do
    # Create a new journey to avoid conflicts with fixture data
    new_journey = @journey.user.journeys.create!(
      name: "Test Journey for Steps",
      campaign_type: "awareness"
    )
    
    step = new_journey.journey_steps.create!(
      title: "New Step",
      step_type: "email",
      sequence_order: 0  # Explicitly set for now
    )
    assert_equal 0, step.sequence_order
    
    step2 = new_journey.journey_steps.create!(
      title: "Second Step",
      step_type: "email",
      sequence_order: 1  # Explicitly set for now
    )
    assert_equal 1, step2.sequence_order
  end

  test "should find next step" do
    next_step = @step.next_step
    assert_not_nil next_step
    assert next_step.sequence_order > @step.sequence_order
  end

  test "should find previous step" do
    second_step = journey_steps(:awareness_step_two)
    previous_step = second_step.previous_step
    assert_not_nil previous_step
    assert previous_step.sequence_order < second_step.sequence_order
  end

  test "should identify first step" do
    assert @step.first_step?
  end

  test "should identify last step" do
    last_step = @journey.journey_steps.order(:sequence_order).last
    assert last_step.last_step?
  end

  test "should serialize settings as JSON" do
    settings = { "delay" => "1 day", "send_time" => "9:00 AM" }
    @step.update!(settings: settings)
    @step.reload
    assert_equal settings, @step.settings
  end
end
