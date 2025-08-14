require "test_helper"

class JourneyTemplateTest < ActiveSupport::TestCase
  def setup
    @template = journey_templates(:awareness_template)
    @user = users(:one)
  end

  test "should validate presence of name" do
    template = JourneyTemplate.new
    template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "should validate uniqueness of name" do
    existing_template = @template
    new_template = JourneyTemplate.new(
      name: existing_template.name,
      campaign_type: "conversion",
      template_data: "{}"
    )
    new_template.valid?
    assert_includes new_template.errors[:name], "has already been taken"
  end

  test "should validate presence of campaign_type" do
    template = JourneyTemplate.new
    template.valid?
    assert_includes template.errors[:campaign_type], "can't be blank"
  end

  test "should validate campaign_type inclusion" do
    template = JourneyTemplate.new(campaign_type: "invalid_type")
    template.valid?
    assert_includes template.errors[:campaign_type], "is not included in the list"
  end

  test "should validate presence of template_data" do
    template = JourneyTemplate.new
    template.valid?
    assert_includes template.errors[:template_data], "can't be blank"
  end

  test "should find default template for campaign type" do
    default_template = JourneyTemplate.default_for_campaign_type("awareness")
    assert_equal @template, default_template
  end

  test "should serialize template_data as JSON" do
    data = { "stages" => ["stage1", "stage2"], "steps" => [] }
    @template.update!(template_data: data)
    @template.reload
    assert_equal data, @template.template_data
  end

  test "should prevent multiple default templates per campaign type" do
    new_template = JourneyTemplate.new(
      name: "Another Awareness Template",
      campaign_type: "awareness",
      template_data: "{}",
      is_default: true
    )
    new_template.valid?
    assert_includes new_template.errors[:is_default], "can only have one default template per campaign type"
  end

  test "should create journey for user" do
    journey_attributes = {
      name: "My Custom Journey",
      description: "A custom journey description"
    }
    
    journey = @template.create_journey_for_user(@user, journey_attributes)
    
    assert journey.persisted?
    assert_equal "My Custom Journey", journey.name
    assert_equal "A custom journey description", journey.description
    assert_equal @template.campaign_type, journey.campaign_type
    assert_equal @user, journey.user
  end

  test "should scope by campaign type" do
    awareness_templates = JourneyTemplate.for_campaign_type("awareness")
    assert_includes awareness_templates, @template
  end

  test "should scope default templates" do
    default_templates = JourneyTemplate.default_templates
    assert_includes default_templates, @template
  end

  # Template customization tests
  test "should clone template with new name" do
    cloned = @template.clone_template(new_name: "Cloned Awareness Template")
    
    assert cloned.persisted?
    assert_equal "Cloned Awareness Template", cloned.name
    assert_equal @template.campaign_type, cloned.campaign_type
    assert_equal @template.description, cloned.description
    assert_equal @template.template_data, cloned.template_data
    assert_not_equal @template.id, cloned.id
    refute cloned.is_default?
  end

  test "should clone template with different campaign type" do
    cloned = @template.clone_template(
      new_name: "Conversion Template", 
      campaign_type: "conversion"
    )
    
    assert_equal "conversion", cloned.campaign_type
  end

  test "should customize stages" do
    new_stages = ["attract", "engage", "convert", "delight"]
    @template.customize_stages(new_stages)
    
    @template.reload
    assert_equal new_stages, @template.template_data["stages"]
  end

  test "should update step stages when customizing stages" do
    # First add some steps with stage references
    @template.update!(template_data: {
      "stages" => ["awareness", "consideration"],
      "steps" => [
        { "title" => "Step 1", "stage" => "awareness" },
        { "title" => "Step 2", "stage" => "consideration" },
        { "title" => "Step 3", "stage" => "awareness" }
      ]
    })
    
    new_stages = ["attract", "convert"]
    @template.customize_stages(new_stages)
    
    @template.reload
    steps = @template.template_data["steps"]
    # Steps should be reassigned to first new stage since old stages don't exist
    assert_equal "attract", steps[0]["stage"]
    assert_equal "attract", steps[1]["stage"] 
    assert_equal "attract", steps[2]["stage"]
  end

  test "should add step to template" do
    initial_steps_count = @template.template_data["steps"]&.length || 0
    
    new_step = {
      "title" => "New Marketing Step",
      "description" => "A custom step",
      "step_type" => "email",
      "channel" => "email"
    }
    
    @template.add_step(new_step)
    @template.reload
    
    steps = @template.template_data["steps"]
    assert_equal initial_steps_count + 1, steps.length
    assert_equal "New Marketing Step", steps.last["title"]
  end

  test "should add step at specific position" do
    @template.update!(template_data: {
      "steps" => [
        { "title" => "Step 1" },
        { "title" => "Step 2" },
        { "title" => "Step 3" }
      ]
    })
    
    new_step = { "title" => "Inserted Step" }
    @template.add_step(new_step, position: 1)
    @template.reload
    
    steps = @template.template_data["steps"]
    assert_equal 4, steps.length
    assert_equal "Inserted Step", steps[1]["title"]
    assert_equal "Step 2", steps[2]["title"]
  end

  test "should remove step by index" do
    @template.update!(template_data: {
      "steps" => [
        { "title" => "Step 1" },
        { "title" => "Step 2" },
        { "title" => "Step 3" }
      ]
    })
    
    result = @template.remove_step(1)
    @template.reload
    
    assert result
    steps = @template.template_data["steps"]
    assert_equal 2, steps.length
    assert_equal "Step 1", steps[0]["title"]
    assert_equal "Step 3", steps[1]["title"]
  end

  test "should return false when removing invalid step index" do
    @template.update!(template_data: { "steps" => [{ "title" => "Step 1" }] })
    
    result = @template.remove_step(5)
    assert_not result
  end

  test "should reorder steps" do
    @template.update!(template_data: {
      "steps" => [
        { "title" => "Step 1" },
        { "title" => "Step 2" },
        { "title" => "Step 3" }
      ]
    })
    
    # Reorder: move first step to last position
    new_order = [1, 2, 0]
    result = @template.reorder_steps(new_order)
    @template.reload
    
    assert result
    steps = @template.template_data["steps"]
    assert_equal "Step 2", steps[0]["title"]
    assert_equal "Step 3", steps[1]["title"]
    assert_equal "Step 1", steps[2]["title"]
  end

  test "should return false when reordering with invalid order array" do
    @template.update!(template_data: {
      "steps" => [{ "title" => "Step 1" }, { "title" => "Step 2" }]
    })
    
    # Wrong length
    result = @template.reorder_steps([0])
    assert_not result
  end

  test "should substitute content type" do
    @template.update!(template_data: {
      "steps" => [
        { "content" => { "type" => "educational" } },
        { "content" => { "type" => "promotional" } },
        { "content" => { "type" => "educational" } }
      ]
    })
    
    result = @template.substitute_content_type("educational", "informational")
    @template.reload
    
    assert result
    steps = @template.template_data["steps"]
    assert_equal "informational", steps[0]["content"]["type"]
    assert_equal "promotional", steps[1]["content"]["type"]
    assert_equal "informational", steps[2]["content"]["type"]
  end

  test "should substitute channel" do
    @template.update!(template_data: {
      "steps" => [
        { "channel" => "email" },
        { "channel" => "social_media" },
        { "channel" => "email" }
      ]
    })
    
    result = @template.substitute_channel("email", "push_notification")
    @template.reload
    
    assert result
    steps = @template.template_data["steps"]
    assert_equal "push_notification", steps[0]["channel"]
    assert_equal "social_media", steps[1]["channel"]
    assert_equal "push_notification", steps[2]["channel"]
  end

  test "should get steps by stage" do
    @template.update!(template_data: {
      "steps" => [
        { "title" => "Step 1", "stage" => "awareness" },
        { "title" => "Step 2", "stage" => "consideration" },
        { "title" => "Step 3", "stage" => "awareness" }
      ]
    })
    
    awareness_steps = @template.get_steps_by_stage("awareness")
    assert_equal 2, awareness_steps.length
    assert_equal "Step 1", awareness_steps[0]["title"]
    assert_equal "Step 3", awareness_steps[1]["title"]
  end

  test "should get metadata fields" do
    @template.update!(template_data: {
      "metadata" => {
        "timeline" => "8-12 weeks",
        "key_metrics" => ["conversion_rate", "engagement"],
        "target_audience" => "B2B prospects"
      }
    })
    
    assert_equal "8-12 weeks", @template.get_timeline
    assert_equal ["conversion_rate", "engagement"], @template.get_key_metrics
    assert_equal "B2B prospects", @template.get_target_audience
  end

  test "should return empty array for key metrics when not present" do
    @template.update!(template_data: { "metadata" => {} })
    assert_equal [], @template.get_key_metrics
  end

  test "should update metadata" do
    @template.update!(template_data: {
      "metadata" => { "timeline" => "old timeline" }
    })
    
    @template.update_metadata({
      "timeline" => "new timeline",
      "key_metrics" => ["new_metric"]
    })
    @template.reload
    
    metadata = @template.template_data["metadata"]
    assert_equal "new timeline", metadata["timeline"]
    assert_equal ["new_metric"], metadata["key_metrics"]
  end
end
