# frozen_string_literal: true

require 'test_helper'

class JourneyCreateFromTemplateTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:marketer_user)
    sign_in_as @user
    
    @template = JourneyTemplate.create!(
      name: "Lead Generation Template",
      description: "Generate qualified leads through multi-channel approach",
      campaign_type: "conversion",
      category: "acquisition",
      industry: "saas",
      complexity_level: "intermediate",
      template_data: {
        "stages" => ["awareness", "interest", "consideration", "conversion"],
        "steps" => [
          {
            "title" => "Lead Magnet Landing Page",
            "description" => "Create compelling lead capture page",
            "step_type" => "landing_page",
            "channel" => "website",
            "stage" => "awareness",
            "content" => {
              "type" => "landing_page",
              "headline" => "Download Our Free Guide"
            },
            "settings" => {
              "delay_days" => 0,
              "trigger" => "immediate"
            }
          },
          {
            "title" => "Welcome Email Sequence",
            "description" => "Nurture new leads with valuable content",
            "step_type" => "email",
            "channel" => "email",
            "stage" => "interest",
            "content" => {
              "type" => "email",
              "subject" => "Welcome to our community!"
            },
            "settings" => {
              "delay_days" => 1,
              "trigger" => "form_submission"
            }
          }
        ],
        "metadata" => {
          "timeline" => "2-3 weeks",
          "key_metrics" => ["conversion_rate", "lead_quality", "cost_per_lead"],
          "target_audience" => "B2B decision makers"
        }
      }
    )
  end

  test "should create journey from template with default name" do
    assert_difference 'Journey.count', 1 do
      post create_from_template_journeys_path, params: {
        template_id: @template.id
      }
    end
    
    journey = Journey.last
    assert_equal "#{@template.name} Journey", journey.name
    assert_equal @template.description, journey.description
    assert_equal @template.campaign_type, journey.campaign_type
    assert_redirected_to edit_journey_path(journey)
    assert_match /created from template/, flash[:notice]
  end

  test "should create journey from template with custom name" do
    custom_name = "My Custom Lead Gen Campaign"
    
    assert_difference 'Journey.count', 1 do
      post create_from_template_journeys_path, params: {
        template_id: @template.id,
        journey_name: custom_name
      }
    end
    
    journey = Journey.last
    assert_equal custom_name, journey.name
    assert_redirected_to edit_journey_path(journey)
  end

  test "should create journey with custom description and template type" do
    custom_description = "Custom description for my campaign"
    template_type = "email"
    
    assert_difference 'Journey.count', 1 do
      post create_from_template_journeys_path, params: {
        template_id: @template.id,
        journey_name: "Custom Journey",
        journey_description: custom_description,
        template_type: template_type
      }
    end
    
    journey = Journey.last
    assert_equal custom_description, journey.description
    assert_equal template_type, journey.template_type
  end

  test "should create journey steps from template" do
    assert_difference 'Journey.count', 1 do
      assert_difference 'JourneyStep.count', 2 do
        post create_from_template_journeys_path, params: {
          template_id: @template.id
        }
      end
    end
    
    journey = Journey.last
    steps = journey.journey_steps.ordered
    
    # Check first step
    first_step = steps.first
    template_step = @template.template_data["steps"].first
    assert_equal template_step["title"], first_step.title
    assert_equal template_step["description"], first_step.description
    assert_equal template_step["step_type"], first_step.step_type
    assert_equal template_step["channel"], first_step.channel
    assert_equal template_step["content"], first_step.content
    assert_equal template_step["settings"], first_step.settings
    assert_equal 0, first_step.sequence_order
    
    # Check second step
    second_step = steps.second
    template_step = @template.template_data["steps"].second
    assert_equal template_step["title"], second_step.title
    assert_equal 1, second_step.sequence_order
  end

  test "should store template metadata in journey" do
    post create_from_template_journeys_path, params: {
      template_id: @template.id
    }
    
    journey = Journey.last
    metadata = journey.metadata
    
    assert_equal @template.id, metadata["template_source"]
    assert_equal @template.name, metadata["template_name"]
    assert_equal @template.campaign_type, metadata["selection_context"]["campaign_type"]
    assert_equal @template.complexity_level, metadata["selection_context"]["complexity_level"]
    assert_equal "template_selection", metadata["selection_context"]["created_via"]
  end

  test "should set journey stages from template" do
    post create_from_template_journeys_path, params: {
      template_id: @template.id
    }
    
    journey = Journey.last
    assert_equal @template.template_data["stages"], journey.stages
  end

  test "should handle template not found" do
    post create_from_template_journeys_path, params: {
      template_id: 99999
    }
    
    assert_redirected_to select_template_journeys_path
    assert_match /Template not found/, flash[:alert]
  end

  test "should handle journey creation failure" do
    # Mock failure by making name too long
    long_name = "a" * 300
    
    assert_no_difference 'Journey.count' do
      post create_from_template_journeys_path, params: {
        template_id: @template.id,
        journey_name: long_name
      }
    end
    
    assert_redirected_to select_template_journeys_path
    assert_match /Failed to create journey/, flash[:alert]
  end

  test "should require authentication" do
    sign_out
    
    post create_from_template_journeys_path, params: {
      template_id: @template.id
    }
    
    assert_redirected_to new_session_path
  end

  test "should authorize journey creation" do
    post create_from_template_journeys_path, params: {
      template_id: @template.id
    }
    
    journey = Journey.last
    assert_equal @user, journey.user
  end

  test "should handle missing template_id parameter" do
    post create_from_template_journeys_path, params: {
      journey_name: "Test Journey"
    }
    
    assert_redirected_to select_template_journeys_path
    assert_match /Template not found/, flash[:alert]
  end

  test "should preserve journey steps order" do
    post create_from_template_journeys_path, params: {
      template_id: @template.id
    }
    
    journey = Journey.last
    steps = journey.journey_steps.order(:sequence_order)
    template_steps = @template.template_data["steps"]
    
    # Verify we have the expected number of steps
    assert_equal template_steps.length, steps.length, "Should create the same number of steps as in template"
    
    # Verify each step has the correct sequence_order
    steps.each_with_index do |step, index|
      assert_equal index, step.sequence_order, "Step at position #{index} should have sequence_order #{index}"
    end
    
    # Verify steps are in the same order as template by checking titles
    steps.each_with_index do |step, index|
      expected_title = template_steps[index]["title"]
      assert_equal expected_title, step.title, "Step at position #{index} should have title '#{expected_title}' but got '#{step.title}'"
    end
    
    # Verify the ordering scope works correctly
    ordered_steps = journey.journey_steps.ordered
    assert_equal steps.map(&:id), ordered_steps.map(&:id), "The ordered scope should return steps in sequence_order"
  end

  test "should handle template with no steps gracefully" do
    @template.update!(template_data: { "stages" => ["awareness"], "steps" => [] })
    
    assert_difference 'Journey.count', 1 do
      assert_no_difference 'JourneyStep.count' do
        post create_from_template_journeys_path, params: {
          template_id: @template.id
        }
      end
    end
    
    journey = Journey.last
    assert_equal 0, journey.journey_steps.count
  end

  test "should skip invalid steps gracefully" do
    # Add invalid step without required fields
    invalid_steps = @template.template_data["steps"] + [
      {
        "description" => "Invalid step without title or step_type"
      }
    ]
    
    @template.update!(template_data: @template.template_data.merge("steps" => invalid_steps))
    
    # Should create journey with only valid steps
    assert_difference 'Journey.count', 1 do
      assert_difference 'JourneyStep.count', 2 do
        post create_from_template_journeys_path, params: {
          template_id: @template.id
        }
      end
    end
    
    journey = Journey.last
    assert_equal 2, journey.journey_steps.count # Only valid steps created
  end

  test "should set journey status to draft" do
    post create_from_template_journeys_path, params: {
      template_id: @template.id
    }
    
    journey = Journey.last
    assert_equal "draft", journey.status
  end

  test "should create journey with template type default" do
    post create_from_template_journeys_path, params: {
      template_id: @template.id
    }
    
    journey = Journey.last
    assert_equal "custom", journey.template_type
  end

  test "should handle AJAX requests" do
    post create_from_template_journeys_path, 
         params: { template_id: @template.id },
         headers: { "X-Requested-With" => "XMLHttpRequest" }
    
    # Should redirect normally for AJAX too
    assert_response :redirect
  end

  test "should merge template metadata correctly" do
    # Test that template metadata doesn't overwrite existing journey metadata
    post create_from_template_journeys_path, params: {
      template_id: @template.id
    }
    
    journey = Journey.last
    intake_metadata = journey.metadata
    
    # Should have template tracking metadata
    assert intake_metadata.key?("template_source")
    assert intake_metadata.key?("template_name") 
    assert intake_metadata.key?("selection_context")
    
    # Selection context should be properly structured
    selection_context = intake_metadata["selection_context"]
    assert_equal @template.campaign_type, selection_context["campaign_type"]
    assert_equal @template.complexity_level, selection_context["complexity_level"]
    assert_equal "template_selection", selection_context["created_via"]
  end
end