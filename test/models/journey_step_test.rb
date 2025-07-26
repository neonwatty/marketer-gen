require "test_helper"

class JourneyStepTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "step_test@example.com",
      password: "password123",
      role: "marketer"
    )
    
    @journey = Journey.create!(
      user: @user,
      name: "Test Journey"
    )
    
    @step = JourneyStep.create!(
      journey: @journey,
      name: "Welcome Email",
      stage: "awareness",
      position: 0,
      content_type: "email",
      channel: "email"
    )
  end
  
  test "should be valid with valid attributes" do
    assert @step.valid?
  end
  
  test "should require a name" do
    @step.name = nil
    assert_not @step.valid?
    assert_includes @step.errors[:name], "can't be blank"
  end
  
  test "should require a journey" do
    step = JourneyStep.new(name: "Test", stage: "awareness")
    assert_not step.valid?
    assert_includes step.errors[:journey], "must exist"
  end
  
  test "should require a valid stage" do
    Journey::STAGES.each do |stage|
      @step.stage = stage
      assert @step.valid?, "#{stage} should be a valid stage"
    end
    
    @step.stage = "invalid_stage"
    assert_not @step.valid?
  end
  
  test "should require a valid content type" do
    JourneyStep::CONTENT_TYPES.each do |type|
      @step.content_type = type
      assert @step.valid?, "#{type} should be a valid content type"
    end
    
    @step.content_type = "invalid_type"
    assert_not @step.valid?
  end
  
  test "should require a valid channel" do
    JourneyStep::CHANNELS.each do |channel|
      @step.channel = channel
      assert @step.valid?, "#{channel} should be a valid channel"
    end
    
    @step.channel = "invalid_channel"
    assert_not @step.valid?
  end
  
  test "should set position automatically on create" do
    # @step already exists with position 0
    step1 = JourneyStep.create!(
      journey: @journey,
      name: "Step 1",
      stage: "awareness"
    )
    
    step2 = JourneyStep.create!(
      journey: @journey,
      name: "Step 2",
      stage: "consideration"
    )
    
    assert_equal 1, step1.position
    assert_equal 2, step2.position
  end
  
  test "should reorder positions after destroy" do
    step1 = JourneyStep.create!(journey: @journey, name: "Step 1", stage: "awareness", position: 1)
    step2 = JourneyStep.create!(journey: @journey, name: "Step 2", stage: "awareness", position: 2)
    step3 = JourneyStep.create!(journey: @journey, name: "Step 3", stage: "awareness", position: 3)
    
    step2.destroy
    
    step1.reload
    step3.reload
    
    assert_equal 1, step1.position
    assert_equal 2, step3.position
  end
  
  test "should move to position correctly" do
    step1 = JourneyStep.create!(journey: @journey, name: "Step 1", stage: "awareness", position: 1)
    step2 = JourneyStep.create!(journey: @journey, name: "Step 2", stage: "awareness", position: 2)
    step3 = JourneyStep.create!(journey: @journey, name: "Step 3", stage: "awareness", position: 3)
    
    step3.move_to_position(1)
    
    step1.reload
    step2.reload
    step3.reload
    
    assert_equal 2, step1.position
    assert_equal 3, step2.position
    assert_equal 1, step3.position
  end
  
  test "should add and remove transitions" do
    step2 = JourneyStep.create!(journey: @journey, name: "Step 2", stage: "consideration")
    
    transition = @step.add_transition_to(step2, { "min_engagement_score" => 5 })
    
    assert transition.persisted?
    assert_equal @step, transition.from_step
    assert_equal step2, transition.to_step
    assert @step.can_transition_to?(step2)
    
    @step.remove_transition_to(step2)
    assert_not @step.can_transition_to?(step2)
  end
  
  test "should evaluate conditions correctly" do
    @step.conditions = {
      "min_engagement_score" => 5,
      "completed_action" => "form_submitted"
    }
    
    context1 = { engagement_score: 6, completed_actions: ["form_submitted"] }
    assert @step.evaluate_conditions(context1)
    
    context2 = { engagement_score: 3, completed_actions: ["form_submitted"] }
    assert_not @step.evaluate_conditions(context2)
    
    context3 = { engagement_score: 6, completed_actions: [] }
    assert_not @step.evaluate_conditions(context3)
  end
  
  test "should export to json format" do
    step2 = JourneyStep.create!(journey: @journey, name: "Step 2", stage: "consideration")
    @step.add_transition_to(step2)
    
    export = @step.to_json_export
    
    assert_equal @step.name, export[:name]
    assert_equal @step.stage, export[:stage]
    assert_equal @step.content_type, export[:content_type]
    assert_equal 1, export[:transitions].size
    assert_equal step2.name, export[:transitions].first[:to]
  end
  
  test "should have proper scopes" do
    step1 = JourneyStep.create!(journey: @journey, name: "S1", stage: "awareness", position: 2)
    step2 = JourneyStep.create!(journey: @journey, name: "S2", stage: "consideration", position: 1)
    step3 = JourneyStep.create!(journey: @journey, name: "S3", stage: "awareness", is_entry_point: true)
    step4 = JourneyStep.create!(journey: @journey, name: "S4", stage: "retention", is_exit_point: true)
    
    # Filter by journey to avoid conflicts with other tests
    ordered = @journey.journey_steps.by_position
    assert_equal @step.id, ordered.first.id  # @step has position 0
    assert_equal step2.id, ordered.second.id  # step2 has position 1
    assert_equal step1.id, ordered.third.id   # step1 has position 2
    
    awareness_steps = @journey.journey_steps.by_stage("awareness")
    assert_includes awareness_steps, @step  # @step is also awareness stage
    assert_includes awareness_steps, step1
    assert_not_includes awareness_steps, step2
    
    assert_includes JourneyStep.entry_points, step3
    assert_includes JourneyStep.exit_points, step4
  end
  
  test "default values should be set" do
    step = JourneyStep.new
    assert_equal 0, step.position
    assert_equal 1, step.duration_days
    assert_equal false, step.is_entry_point
    assert_equal false, step.is_exit_point
    assert_equal({}, step.config)
    assert_equal({}, step.conditions)
    assert_equal({}, step.metadata)
  end
end