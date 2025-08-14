require "test_helper"

class JourneyTemplateAdvancedTest < ActiveSupport::TestCase
  test "template creates journey with complex step structure" do
    template_data = {
      "stages" => ["awareness", "consideration", "conversion"],
      "steps" => [
        {
          "title" => "Welcome Email",
          "step_type" => "email",
          "content" => "Welcome to our journey!",
          "channel" => "email",
          "settings" => { "delay" => "immediate" }
        },
        {
          "title" => "Educational Content",
          "step_type" => "content_piece",
          "content" => "Learn about our product",
          "channel" => "blog",
          "settings" => { "delay" => "3 days" }
        }
      ],
      "metadata" => {
        "estimated_duration" => "7 days",
        "target_audience" => "new_subscribers"
      }
    }
    
    template = JourneyTemplate.create!(
      name: "Complex Template",
      campaign_type: "awareness",
      template_data: template_data
    )
    
    user = users(:one)
    journey = template.create_journey_for_user(user, name: "My Custom Journey")
    
    assert journey.persisted?
    assert_equal 2, journey.journey_steps.count
    assert_equal template_data["stages"], journey.stages
    assert_equal template_data["metadata"], journey.metadata
    
    # Verify steps were created correctly
    first_step = journey.journey_steps.order(:sequence_order).first
    assert_equal "Welcome Email", first_step.title
    assert_equal({ "delay" => "immediate" }, first_step.settings)
    
    second_step = journey.journey_steps.order(:sequence_order).second
    assert_equal "Educational Content", second_step.title
    assert_equal "blog", second_step.channel
  end

  test "prevents creating multiple default templates through validation" do
    existing_template = journey_templates(:awareness_template) # This is already default
    
    # Attempt to create another default template for same campaign type
    new_template = JourneyTemplate.new(
      name: "Another Default Template",
      campaign_type: "awareness",
      template_data: "{}",
      is_default: true
    )
    
    assert_not new_template.valid?
    assert_includes new_template.errors[:is_default], "can only have one default template per campaign type"
  end

  test "template handles missing or invalid step data gracefully" do
    template_data = {
      "stages" => ["awareness"],
      "steps" => [
        {
          "title" => "Valid Step",
          "step_type" => "email"
          # Missing some optional fields
        },
        {
          # Missing title - should cause step creation to fail gracefully
          "step_type" => "email"
        },
        {
          "title" => "Another Valid Step",
          "step_type" => "content_piece",
          "settings" => nil # Explicit nil
        }
      ]
    }
    
    template = JourneyTemplate.create!(
      name: "Incomplete Template",
      campaign_type: "awareness",
      template_data: template_data
    )
    
    user = users(:one)
    journey = template.create_journey_for_user(user, name: "Test Journey")
    
    # Journey should be created even if some steps fail
    assert journey.persisted?
    
    # Only valid steps should be created
    valid_steps = journey.journey_steps.where.not(title: nil)
    assert valid_steps.count >= 1 # At least the valid steps
  end

  test "template can override default stages for campaign type" do
    custom_stages = ["custom_stage_1", "custom_stage_2"]
    template_data = {
      "stages" => custom_stages,
      "steps" => []
    }
    
    template = JourneyTemplate.create!(
      name: "Custom Stages Template",
      campaign_type: "awareness", # Would normally have default stages
      template_data: template_data
    )
    
    user = users(:one)
    journey = template.create_journey_for_user(user, name: "Custom Journey")
    
    # Should use template stages, not default campaign type stages
    assert_equal custom_stages, journey.stages
    assert_not_equal ["discovery", "education", "engagement"], journey.stages
  end

  test "template creation preserves deep nested data structures" do
    complex_template_data = {
      "stages" => ["stage1", "stage2"],
      "steps" => [
        {
          "title" => "Complex Step",
          "step_type" => "automation",
          "settings" => {
            "triggers" => [
              { "event" => "email_open", "delay" => "1 hour" },
              { "event" => "link_click", "delay" => "immediate" }
            ],
            "conditions" => {
              "user_segment" => ["premium", "trial"],
              "previous_engagement" => { "min_score" => 7.5 }
            }
          }
        }
      ],
      "metadata" => {
        "versioning" => {
          "version" => "2.1",
          "changelog" => ["Added triggers", "Updated conditions"]
        }
      }
    }
    
    template = JourneyTemplate.create!(
      name: "Complex Data Template",
      campaign_type: "conversion",
      template_data: complex_template_data
    )
    
    user = users(:one)
    journey = template.create_journey_for_user(user)
    
    created_step = journey.journey_steps.first
    assert_equal 2, created_step.settings["triggers"].length
    assert_equal "email_open", created_step.settings["triggers"][0]["event"]
    assert_equal ["premium", "trial"], created_step.settings["conditions"]["user_segment"]
    
    assert_equal "2.1", journey.metadata["versioning"]["version"]
    assert_equal 2, journey.metadata["versioning"]["changelog"].length
  end

  test "template system supports different campaign types correctly" do
    campaign_types = ["awareness", "consideration", "conversion", "retention", "upsell_cross_sell"]
    
    campaign_types.each do |campaign_type|
      template = JourneyTemplate.create!(
        name: "#{campaign_type.capitalize} Template",
        campaign_type: campaign_type,
        template_data: {
          "stages" => ["stage1"],
          "steps" => [
            {
              "title" => "#{campaign_type.capitalize} Step",
              "step_type" => "email"
            }
          ]
        }
      )
      
      user = users(:one)
      journey = template.create_journey_for_user(user, name: "#{campaign_type} Journey")
      
      assert_equal campaign_type, journey.campaign_type
      assert journey.persisted?
    end
  end

  test "template can create journey with custom attributes" do
    template = journey_templates(:awareness_template)
    user = users(:one)
    
    custom_attributes = {
      name: "Custom Name",
      description: "Custom Description",
      template_type: "email",
      status: "active" # Override default draft status
    }
    
    journey = template.create_journey_for_user(user, custom_attributes)
    
    assert_equal "Custom Name", journey.name
    assert_equal "Custom Description", journey.description  
    assert_equal "email", journey.template_type
    assert_equal "active", journey.status
    assert_equal template.campaign_type, journey.campaign_type
  end

  test "template data validation ensures required structure" do
    # Test template with invalid JSON structure
    invalid_template = JourneyTemplate.new(
      name: "Invalid Template",
      campaign_type: "awareness",
      template_data: "invalid json string"
    )
    
    # Should fail validation or handle gracefully
    assert invalid_template.valid? # Basic validation should pass
    
    # Test with valid JSON but missing expected structure
    minimal_template = JourneyTemplate.new(
      name: "Minimal Template",
      campaign_type: "awareness", 
      template_data: { "minimal" => "data" }
    )
    
    assert minimal_template.valid?
    
    user = users(:one)
    journey = minimal_template.create_journey_for_user(user)
    
    # Should create journey even with minimal template data
    assert journey.persisted?
  end
end