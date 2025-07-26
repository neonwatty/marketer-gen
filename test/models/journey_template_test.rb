require "test_helper"

class JourneyTemplateTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "template_test@example.com",
      password: "password123",
      role: "marketer"
    )
    
    @template = JourneyTemplate.create!(
      name: "Test Template",
      description: "A test template for marketing",
      category: "b2b",
      campaign_type: "lead_generation",
      difficulty_level: "intermediate",
      estimated_duration_days: 14,
      template_data: {
        steps: [
          {
            id: "step1",
            name: "Welcome Email",
            stage: "awareness",
            content_type: "email",
            channel: "email",
            is_entry_point: true
          },
          {
            id: "step2", 
            name: "Follow-up",
            stage: "consideration",
            content_type: "email",
            channel: "email",
            is_exit_point: true
          }
        ],
        transitions: [
          {
            from_step_id: "step1",
            to_step_id: "step2",
            transition_type: "sequential"
          }
        ]
      }
    )
  end

  test "should create journey template with valid attributes" do
    template = JourneyTemplate.new(
      name: "New Template",
      description: "Another test template",
      category: "saas",
      campaign_type: "customer_retention",
      difficulty_level: "beginner",
      estimated_duration_days: 7,
      template_data: { steps: [], transitions: [] }
    )
    
    assert template.valid?
    assert template.save
  end

  test "should require name" do
    @template.name = nil
    assert_not @template.valid?
    assert_includes @template.errors[:name], "can't be blank"
  end

  test "should require category" do
    @template.category = nil
    assert_not @template.valid?
    assert_includes @template.errors[:category], "can't be blank"
  end

  test "should validate category inclusion" do
    @template.category = "invalid_category"
    assert_not @template.valid?
    assert_includes @template.errors[:category], "is not included in the list"
  end

  test "should validate campaign type inclusion" do
    @template.campaign_type = "invalid_type"
    assert_not @template.valid?
    assert_includes @template.errors[:campaign_type], "is not included in the list"
  end

  test "should validate difficulty level inclusion" do
    @template.difficulty_level = "expert"
    assert_not @template.valid?
    assert_includes @template.errors[:difficulty_level], "is not included in the list"
  end

  test "should validate estimated duration is positive" do
    @template.estimated_duration_days = -5
    assert_not @template.valid?
    assert_includes @template.errors[:estimated_duration_days], "must be greater than 0"
  end

  test "should have default version of 1.0" do
    template = JourneyTemplate.create!(
      name: "Version Test Template",
      category: "b2c",
      template_data: { steps: [] }
    )
    
    assert_equal 1.0, template.version
  end

  test "should be original template by default" do
    assert @template.is_original?
    assert_nil @template.original_template_id
    assert_equal @template, @template.root_template
  end

  test "preview_steps should return steps from template_data" do
    steps = @template.preview_steps
    assert_equal 2, steps.size
    assert_equal "Welcome Email", steps.first["name"]
    assert_equal "Follow-up", steps.last["name"]
  end

  test "step_count should return number of steps" do
    assert_equal 2, @template.step_count
  end

  test "stages_covered should return unique stages" do
    stages = @template.stages_covered
    assert_equal 2, stages.size
    assert_includes stages, "awareness"
    assert_includes stages, "consideration"
  end

  test "channels_used should return unique channels" do
    channels = @template.channels_used
    assert_equal 1, channels.size
    assert_includes channels, "email"
  end

  test "content_types_included should return unique content types" do
    types = @template.content_types_included
    assert_equal 1, types.size
    assert_includes types, "email"
  end

  test "create_journey_for_user should create journey with steps" do
    journey = @template.create_journey_for_user(@user, name: "Test Journey")
    
    assert journey.persisted?
    assert_equal "Test Journey", journey.name
    assert_equal @template.description, journey.description
    assert_equal @template.campaign_type, journey.campaign_type
    assert_equal @template.id, journey.metadata["template_id"]
    assert_equal 2, journey.journey_steps.count
    
    # Check steps were created properly
    welcome_step = journey.journey_steps.find_by(name: "Welcome Email")
    assert welcome_step
    assert welcome_step.is_entry_point?
    assert_equal "awareness", welcome_step.stage
    
    followup_step = journey.journey_steps.find_by(name: "Follow-up")
    assert followup_step
    assert followup_step.is_exit_point?
    assert_equal "consideration", followup_step.stage
    
    # Check transitions were created
    assert_equal 1, welcome_step.transitions_from.count
    transition = welcome_step.transitions_from.first
    assert_equal followup_step, transition.to_step
    assert_equal "sequential", transition.transition_type
  end

  test "create_journey_for_user should increment usage_count" do
    initial_count = @template.usage_count
    @template.create_journey_for_user(@user)
    
    @template.reload
    assert_equal initial_count + 1, @template.usage_count
  end

  test "scopes should work correctly" do
    # Test active scope
    @template.update!(is_active: false)
    assert_not JourneyTemplate.active.include?(@template)
    
    @template.update!(is_active: true)
    assert JourneyTemplate.active.include?(@template)
    
    # Test by_category scope
    assert JourneyTemplate.by_category("b2b").include?(@template)
    assert_not JourneyTemplate.by_category("saas").include?(@template)
    
    # Test by_campaign_type scope
    assert JourneyTemplate.by_campaign_type("lead_generation").include?(@template)
    assert_not JourneyTemplate.by_campaign_type("email_nurture").include?(@template)
  end

  test "create_new_version should create new version with incremented number" do
    new_version = @template.create_new_version(version_notes: "Added new features")
    
    assert_equal 1.01, new_version.version
    assert_equal @template, new_version.original_template
    assert_equal @template.version, new_version.parent_version
    assert_equal "Added new features", new_version.version_notes
    assert_not new_version.is_published_version
    assert_equal 0, new_version.usage_count
    assert new_version.is_active
  end

  test "publish_version should unpublish other versions" do
    new_version = @template.create_new_version
    new_version.save!
    
    # Original should be published, new version should not be
    assert @template.is_published_version
    assert_not new_version.is_published_version
    
    # Publishing new version should unpublish original
    new_version.publish_version!
    
    @template.reload
    assert_not @template.is_published_version
    assert new_version.is_published_version
  end

  test "version_history should return version information" do
    new_version = @template.create_new_version(version_notes: "Version 1.01")
    new_version.save!
    
    history = @template.version_history
    assert_equal 2, history.size
    
    v1 = history.find { |v| v[:version] == 1.0 }
    v101 = history.find { |v| v[:version] == 1.01 }
    
    assert v1
    assert v101
    assert_equal "Version 1.01", v101[:version_notes]
  end

  test "all_versions should return all versions including original" do
    new_version = @template.create_new_version
    new_version.save!
    
    versions = @template.all_versions
    assert_equal 2, versions.size
    assert_includes versions, @template
    assert_includes versions, new_version
  end

  test "latest_version should return highest version number" do
    new_version = @template.create_new_version
    new_version.save!
    
    assert_equal new_version, @template.latest_version
    assert_equal new_version, new_version.latest_version
  end
end
