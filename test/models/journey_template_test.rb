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
    data = { "stages" => [ "stage1", "stage2" ], "steps" => [] }
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
    new_stages = [ "attract", "engage", "convert", "delight" ]
    @template.customize_stages(new_stages)

    @template.reload
    assert_equal new_stages, @template.template_data["stages"]
  end

  test "should update step stages when customizing stages" do
    # First add some steps with stage references
    @template.update!(template_data: {
      "stages" => [ "awareness", "consideration" ],
      "steps" => [
        { "title" => "Step 1", "stage" => "awareness" },
        { "title" => "Step 2", "stage" => "consideration" },
        { "title" => "Step 3", "stage" => "awareness" }
      ]
    })

    new_stages = [ "attract", "convert" ]
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
    @template.update!(template_data: { "steps" => [ { "title" => "Step 1" } ] })

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
    new_order = [ 1, 2, 0 ]
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
      "steps" => [ { "title" => "Step 1" }, { "title" => "Step 2" } ]
    })

    # Wrong length
    result = @template.reorder_steps([ 0 ])
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
        "key_metrics" => [ "conversion_rate", "engagement" ],
        "target_audience" => "B2B prospects"
      }
    })

    assert_equal "8-12 weeks", @template.get_timeline
    assert_equal [ "conversion_rate", "engagement" ], @template.get_key_metrics
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
      "key_metrics" => [ "new_metric" ]
    })
    @template.reload

    metadata = @template.template_data["metadata"]
    assert_equal "new timeline", metadata["timeline"]
    assert_equal [ "new_metric" ], metadata["key_metrics"]
  end

  # New metadata field validation tests
  test "should validate category inclusion" do
    template = JourneyTemplate.new(
      name: "Test Template",
      campaign_type: "awareness",
      template_data: "{}",
      category: "invalid_category"
    )
    template.valid?
    assert_includes template.errors[:category], "is not included in the list"
  end

  test "should allow blank category" do
    template = JourneyTemplate.new(
      name: "Test Template",
      campaign_type: "awareness",
      template_data: "{}",
      category: ""
    )
    template.valid?
    assert_not_includes template.errors[:category], "is not included in the list"
  end

  test "should validate industry inclusion" do
    template = JourneyTemplate.new(
      name: "Test Template",
      campaign_type: "awareness",
      template_data: "{}",
      industry: "invalid_industry"
    )
    template.valid?
    assert_includes template.errors[:industry], "is not included in the list"
  end

  test "should validate complexity_level inclusion" do
    template = JourneyTemplate.new(
      name: "Test Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "invalid_level"
    )
    template.valid?
    assert_includes template.errors[:complexity_level], "is not included in the list"
  end

  test "should validate prerequisites length" do
    long_prerequisites = "a" * 2001
    template = JourneyTemplate.new(
      name: "Test Template",
      campaign_type: "awareness",
      template_data: "{}",
      prerequisites: long_prerequisites
    )
    template.valid?
    assert_includes template.errors[:prerequisites], "is too long (maximum is 2000 characters)"
  end

  # Scope tests for new metadata fields
  test "should scope by category" do
    template1 = JourneyTemplate.create!(
      name: "Acquisition Template",
      campaign_type: "awareness",
      template_data: "{}",
      category: "acquisition"
    )
    template2 = JourneyTemplate.create!(
      name: "Retention Template",
      campaign_type: "retention",
      template_data: "{}",
      category: "retention"
    )

    acquisition_templates = JourneyTemplate.by_category("acquisition")
    assert_includes acquisition_templates, template1
    assert_not_includes acquisition_templates, template2
  end

  test "should scope by industry" do
    template1 = JourneyTemplate.create!(
      name: "Tech Template",
      campaign_type: "awareness",
      template_data: "{}",
      industry: "technology"
    )
    template2 = JourneyTemplate.create!(
      name: "Healthcare Template",
      campaign_type: "awareness",
      template_data: "{}",
      industry: "healthcare"
    )

    tech_templates = JourneyTemplate.by_industry("technology")
    assert_includes tech_templates, template1
    assert_not_includes tech_templates, template2
  end

  test "should scope by complexity level" do
    template1 = JourneyTemplate.create!(
      name: "Beginner Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "beginner"
    )
    template2 = JourneyTemplate.create!(
      name: "Expert Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "expert"
    )

    beginner_templates = JourneyTemplate.by_complexity("beginner")
    assert_includes beginner_templates, template1
    assert_not_includes beginner_templates, template2
  end

  test "should scope for beginner level" do
    template1 = JourneyTemplate.create!(
      name: "Beginner Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "beginner"
    )
    template2 = JourneyTemplate.create!(
      name: "Advanced Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "advanced"
    )

    beginner_templates = JourneyTemplate.for_beginner
    assert_includes beginner_templates, template1
    assert_not_includes beginner_templates, template2
  end

  test "should scope for advanced level" do
    template1 = JourneyTemplate.create!(
      name: "Advanced Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "advanced"
    )
    template2 = JourneyTemplate.create!(
      name: "Expert Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "expert"
    )
    template3 = JourneyTemplate.create!(
      name: "Beginner Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "beginner"
    )

    advanced_templates = JourneyTemplate.for_advanced
    assert_includes advanced_templates, template1
    assert_includes advanced_templates, template2
    assert_not_includes advanced_templates, template3
  end

  test "should scope with prerequisites" do
    template1 = JourneyTemplate.create!(
      name: "Template with Prerequisites",
      campaign_type: "awareness",
      template_data: "{}",
      prerequisites: "Basic marketing knowledge required"
    )
    template2 = JourneyTemplate.create!(
      name: "Template without Prerequisites",
      campaign_type: "awareness",
      template_data: "{}"
    )

    templates_with_prereqs = JourneyTemplate.with_prerequisites
    assert_includes templates_with_prereqs, template1
    assert_not_includes templates_with_prereqs, template2
  end

  test "should scope without prerequisites" do
    template1 = JourneyTemplate.create!(
      name: "Template with Prerequisites",
      campaign_type: "awareness",
      template_data: "{}",
      prerequisites: "Basic marketing knowledge required"
    )
    template2 = JourneyTemplate.create!(
      name: "Template without Prerequisites",
      campaign_type: "awareness",
      template_data: "{}"
    )

    templates_without_prereqs = JourneyTemplate.without_prerequisites
    assert_not_includes templates_without_prereqs, template1
    assert_includes templates_without_prereqs, template2
  end

  # Class method tests for filtering and search
  test "should filter by multiple criteria" do
    template1 = JourneyTemplate.create!(
      name: "Tech Acquisition Template",
      campaign_type: "awareness",
      template_data: "{}",
      category: "acquisition",
      industry: "technology",
      complexity_level: "beginner"
    )
    template2 = JourneyTemplate.create!(
      name: "Healthcare Retention Template",
      campaign_type: "retention",
      template_data: "{}",
      category: "retention",
      industry: "healthcare",
      complexity_level: "advanced"
    )

    criteria = {
      category: "acquisition",
      industry: "technology",
      complexity_level: "beginner"
    }
    filtered_templates = JourneyTemplate.filter_by_criteria(criteria)

    assert_includes filtered_templates, template1
    assert_not_includes filtered_templates, template2
  end

  test "should filter by has_prerequisites criteria" do
    template1 = JourneyTemplate.create!(
      name: "Template with Prerequisites",
      campaign_type: "awareness",
      template_data: "{}",
      prerequisites: "Some requirements"
    )
    template2 = JourneyTemplate.create!(
      name: "Template without Prerequisites",
      campaign_type: "awareness",
      template_data: "{}"
    )

    # Filter for templates with prerequisites
    filtered_with = JourneyTemplate.filter_by_criteria(has_prerequisites: true)
    assert_includes filtered_with, template1
    assert_not_includes filtered_with, template2

    # Filter for templates without prerequisites
    filtered_without = JourneyTemplate.filter_by_criteria(has_prerequisites: false)
    assert_not_includes filtered_without, template1
    assert_includes filtered_without, template2
  end

  test "should search by metadata" do
    template1 = JourneyTemplate.create!(
      name: "Product Launch Template",
      campaign_type: "awareness",
      template_data: "{}",
      description: "Launch new products effectively",
      prerequisites: "Product development team"
    )
    template2 = JourneyTemplate.create!(
      name: "Brand Awareness Template",
      campaign_type: "awareness",
      template_data: "{}",
      description: "Build brand recognition"
    )

    # Search by name
    results = JourneyTemplate.search_by_metadata("product")
    assert_includes results, template1
    assert_not_includes results, template2

    # Search by description
    results = JourneyTemplate.search_by_metadata("brand")
    assert_includes results, template2
    assert_not_includes results, template1

    # Search by prerequisites
    results = JourneyTemplate.search_by_metadata("development")
    assert_includes results, template1
    assert_not_includes results, template2
  end

  test "should return all templates for blank search query" do
    template1 = JourneyTemplate.create!(
      name: "Template 1",
      campaign_type: "awareness",
      template_data: "{}"
    )
    template2 = JourneyTemplate.create!(
      name: "Template 2",
      campaign_type: "retention",
      template_data: "{}"
    )

    results = JourneyTemplate.search_by_metadata("")
    assert_includes results, template1
    assert_includes results, template2
  end

  test "should recommend templates for user" do
    template1 = JourneyTemplate.create!(
      name: "Beginner Tech Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "beginner",
      industry: "technology"
    )
    template2 = JourneyTemplate.create!(
      name: "Advanced Healthcare Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "advanced",
      industry: "healthcare"
    )

    recommendations = JourneyTemplate.recommended_for_user(
      user_skill_level: "beginner",
      industry: "technology",
      campaign_type: "awareness"
    )

    assert_includes recommendations, template1
    assert_not_includes recommendations, template2
  end

  # Instance method tests for metadata
  test "should return metadata summary" do
    @template.update!(
      category: "acquisition",
      industry: "technology",
      complexity_level: "intermediate",
      prerequisites: "Marketing team, Budget allocated"
    )

    summary = @template.metadata_summary

    assert_equal "acquisition", summary[:category]
    assert_equal "technology", summary[:industry]
    assert_equal "intermediate", summary[:complexity_level]
    assert_equal true, summary[:has_prerequisites]
    assert_equal 2, summary[:prerequisites_count]
  end

  test "should identify suitable for beginner" do
    template1 = JourneyTemplate.create!(
      name: "Beginner Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "beginner"
    )
    template2 = JourneyTemplate.create!(
      name: "Advanced Template",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "advanced"
    )
    template3 = JourneyTemplate.create!(
      name: "Beginner with Prerequisites",
      campaign_type: "awareness",
      template_data: "{}",
      complexity_level: "beginner",
      prerequisites: "Some requirements"
    )

    assert template1.suitable_for_beginner?
    assert_not template2.suitable_for_beginner?
    assert_not template3.suitable_for_beginner?
  end

  test "should identify templates requiring prerequisites" do
    template1 = JourneyTemplate.create!(
      name: "Template with Prerequisites",
      campaign_type: "awareness",
      template_data: "{}",
      prerequisites: "Some requirements"
    )
    template2 = JourneyTemplate.create!(
      name: "Template without Prerequisites",
      campaign_type: "awareness",
      template_data: "{}"
    )

    assert template1.requires_prerequisites?
    assert_not template2.requires_prerequisites?
  end
end
