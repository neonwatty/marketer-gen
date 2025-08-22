# frozen_string_literal: true

require 'test_helper'

class JourneyTemplatePreviewTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:marketer_user)
    sign_in_as @user
    
    @template = JourneyTemplate.create!(
      name: "Test Template",
      description: "A test template for previewing",
      campaign_type: "awareness",
      category: "acquisition", 
      industry: "technology",
      complexity_level: "intermediate",
      prerequisites: "Basic marketing knowledge required",
      template_data: {
        "stages" => ["awareness", "interest", "consideration"],
        "steps" => [
          {
            "title" => "Welcome Email",
            "description" => "Send personalized welcome message to new subscribers",
            "step_type" => "email",
            "channel" => "email",
            "stage" => "awareness"
          },
          {
            "title" => "Social Media Post",
            "description" => "Share engaging content on social platforms",
            "step_type" => "social_media", 
            "channel" => "social",
            "stage" => "interest"
          }
        ],
        "metadata" => {
          "timeline" => "4-6 weeks",
          "key_metrics" => ["open_rate", "click_rate", "engagement"],
          "target_audience" => "New subscribers interested in technology"
        }
      }
    )
  end

  test "should show template preview" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select "h4", @template.name
    assert_select ".text-gray-600", @template.description
  end

  test "should display template metadata in preview" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select ".bg-blue-100", @template.campaign_type.humanize
    assert_select ".bg-yellow-100", @template.complexity_level.humanize
    assert_select ".bg-gray-100", @template.industry.humanize
  end

  test "should show template overview stats" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    
    # Check stages count
    assert_select ".text-2xl", @template.template_data["stages"].length.to_s
    
    # Check steps count
    assert_select ".text-2xl", @template.template_data["steps"].length.to_s
    
    # Check timeline
    assert_select ".text-2xl", @template.get_timeline
  end

  test "should display target audience" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select "h5", "Target Audience"
    assert_select ".text-sm", @template.get_target_audience
  end

  test "should show key metrics" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select "h5", "Key Metrics"
    
    @template.get_key_metrics.each do |metric|
      assert_select ".bg-blue-50", metric
    end
  end

  test "should display journey stages" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select "h5", "Journey Stages"
    
    @template.template_data["stages"].each_with_index do |stage, index|
      assert_select ".text-blue-600", (index + 1).to_s
      assert_select ".text-sm", stage.humanize
    end
  end

  test "should show sample steps" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select "h5", "Sample Steps"
    
    # Should show up to 5 steps
    expected_steps = @template.template_data["steps"].first(5)
    expected_steps.each do |step|
      assert_select ".text-sm", step["title"]
      if step["description"]
        assert_select ".text-xs", /#{step["description"][0..20]}/
      end
    end
  end

  test "should display step metadata" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    
    @template.template_data["steps"].first(5).each do |step|
      if step["step_type"]
        assert_select ".bg-gray-100", step["step_type"].humanize
      end
      if step["channel"]
        assert_select ".bg-blue-100", step["channel"].humanize
      end
    end
  end

  test "should show prerequisites warning" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select "h5", "Prerequisites"
    assert_select ".bg-yellow-50", /#{@template.prerequisites}/
  end

  test "should not show prerequisites section if none" do
    @template.update!(prerequisites: "")
    
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select "h5", { text: "Prerequisites", count: 0 }
  end

  test "should show action buttons" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select "button", "Close"
    assert_select "input[type='submit'][value='Use This Template']"
  end

  test "should include template creation form" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select "form[action='#{create_from_template_journeys_path}']"
    assert_select "input[name='template_id'][value='#{@template.id}']"
    assert_select "input[name='journey_name'][value='#{@template.name} Journey']"
  end

  test "should handle templates with many steps" do
    # Create template with more than 5 steps
    many_steps = (1..8).map do |i|
      {
        "title" => "Step #{i}",
        "description" => "Description for step #{i}",
        "step_type" => "email",
        "channel" => "email", 
        "stage" => "awareness"
      }
    end
    
    @template.update!(template_data: @template.template_data.merge("steps" => many_steps))
    
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    assert_select ".text-sm", "... and 3 more steps"
  end

  test "should work without layout for modal display" do
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    # Should render template content for modal display
    assert_select "h4", @template.name
    assert_select ".space-y-6" # Main container div
  end

  test "should respond to turbo stream requests" do
    get template_preview_journeys_path(template_id: @template.id),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should handle missing template gracefully" do
    get template_preview_journeys_path(template_id: 99999)
    
    assert_response :not_found
  end

  test "should require authentication" do
    sign_out
    
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_redirected_to new_session_path
  end

  test "should authorize template access" do
    # Test authorization would go here if templates had user restrictions
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
  end

  test "should show truncated step descriptions" do
    long_description = "A" * 200
    step_with_long_desc = @template.template_data["steps"].first.dup
    step_with_long_desc["description"] = long_description
    
    @template.template_data["steps"][0] = step_with_long_desc
    @template.save!
    
    get template_preview_journeys_path(template_id: @template.id)
    
    assert_response :success
    # Should truncate to ~100 characters
    assert_select ".text-xs", /#{long_description[0..20]}/
    assert_match /\.\.\./, @response.body
  end
end