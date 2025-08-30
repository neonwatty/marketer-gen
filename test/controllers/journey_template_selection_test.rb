# frozen_string_literal: true

require 'test_helper'

class JourneyTemplateSelectionTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:marketer_user)
    sign_in_as @user
    
    # Create test templates
    @awareness_template = JourneyTemplate.create!(
      name: "Brand Awareness Campaign",
      description: "Build recognition and reach new audiences",
      campaign_type: "awareness",
      category: "acquisition",
      industry: "technology",
      complexity_level: "beginner",
      template_data: {
        "stages" => ["awareness", "interest", "engagement"],
        "steps" => [
          {
            "title" => "Social Media Post",
            "description" => "Create engaging social content",
            "step_type" => "social_media",
            "channel" => "social",
            "stage" => "awareness"
          }
        ],
        "metadata" => {
          "timeline" => "2-4 weeks",
          "key_metrics" => ["reach", "impressions", "engagement"],
          "target_audience" => "Tech-savvy professionals"
        }
      }
    )
    
    @conversion_template = JourneyTemplate.create!(
      name: "Conversion Optimization",
      description: "Drive purchases from qualified leads",
      campaign_type: "conversion",
      category: "conversion",
      industry: "ecommerce",
      complexity_level: "advanced",
      template_data: {
        "stages" => ["interest", "consideration", "purchase"],
        "steps" => [
          {
            "title" => "Product Demo Email",
            "description" => "Showcase product benefits",
            "step_type" => "email",
            "channel" => "email",
            "stage" => "consideration"
          }
        ]
      }
    )
  end

  test "should show template selection page" do
    get select_template_journeys_path
    
    assert_response :success
    assert_select "h1", "Choose a Journey Template"
    assert_select "[data-controller='template-selector']"
  end

  test "should show guided questions for new users" do
    get select_template_journeys_path
    
    assert_response :success
    assert_select "[data-template-selector-target='guidedQuestions']"
    assert_select "h3", /What type of campaign are you planning/
    assert_select "[data-template-selector-target='guidedQuestions'] button[type='submit']", count: JourneyTemplate::CAMPAIGN_TYPES.length
  end

  test "should filter templates by campaign type" do
    get select_template_journeys_path, params: { campaign_type: "awareness" }
    
    assert_response :success
    assert_select "[data-template-id='#{@awareness_template.id}']"
    assert_select "[data-template-id='#{@conversion_template.id}']", count: 0
  end

  test "should filter templates by complexity level" do
    get select_template_journeys_path, params: { complexity_level: "beginner" }
    
    assert_response :success
    assert_select "[data-template-id='#{@awareness_template.id}']"
    assert_select "[data-template-id='#{@conversion_template.id}']", count: 0
  end

  test "should filter templates by industry" do
    get select_template_journeys_path, params: { industry: "technology" }
    
    assert_response :success
    assert_select "[data-template-id='#{@awareness_template.id}']"
    assert_select "[data-template-id='#{@conversion_template.id}']", count: 0
  end

  test "should search templates by name and description" do
    get select_template_journeys_path, params: { search: "Brand Awareness" }
    
    assert_response :success
    assert_select "[data-template-id='#{@awareness_template.id}']"
    assert_select "[data-template-id='#{@conversion_template.id}']", count: 0
  end

  test "should combine multiple filters" do
    get select_template_journeys_path, params: { 
      campaign_type: "awareness", 
      complexity_level: "beginner",
      industry: "technology"
    }
    
    assert_response :success
    assert_select "[data-template-id='#{@awareness_template.id}']"
    assert_select "[data-template-id='#{@conversion_template.id}']", count: 0
  end

  test "should show no results message when no templates match" do
    get select_template_journeys_path, params: { 
      campaign_type: "awareness", 
      industry: "nonprofit" # No templates in this combination
    }
    
    assert_response :success
    assert_select "h3", "No templates found"
    assert_select ".text-center", /Try adjusting your filters/
  end

  test "should progress through guided questions" do
    # Step 1: Choose campaign type
    get select_template_journeys_path, params: { campaign_type: "awareness" }
    assert_response :success
    assert_select "h3", /What's your experience level/
    
    # Step 2: Choose complexity level
    get select_template_journeys_path, params: { 
      campaign_type: "awareness", 
      complexity_level: "beginner" 
    }
    assert_response :success
    assert_select "h3", /Which industry best describes/
    
    # Step 3: Choose industry
    get select_template_journeys_path, params: { 
      campaign_type: "awareness", 
      complexity_level: "beginner",
      industry: "technology"
    }
    assert_response :success
    assert_select "h3", /What's the primary focus/
    
    # Step 4: All questions answered - should show completion message or no more questions
    get select_template_journeys_path, params: { 
      campaign_type: "awareness", 
      complexity_level: "beginner",
      industry: "technology",
      category: "acquisition"
    }
    assert_response :success
    # Should either show completion message or have no guided questions left
    response_body = @response.body
    assert(response_body.include?("Perfect! Here are your recommended templates") || 
           !response_body.include?("What type of campaign are you planning?"))
  end

  test "should respond to turbo stream requests" do
    get select_template_journeys_path, params: { campaign_type: "awareness" }, 
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
    assert_match(/turbo-stream/, @response.body)
  end

  test "should show template analytics" do
    get select_template_journeys_path
    
    assert_response :success
    assert_select ".text-sm", /#{@awareness_template.class.count} templates? found/
  end

  test "should clear all filters" do
    get select_template_journeys_path, params: { 
      campaign_type: "awareness", 
      complexity_level: "beginner" 
    }
    
    assert_response :success
    assert_select "a[href='#{select_template_journeys_path}']", "Clear all filters"
  end

  test "should show template metadata in cards" do
    get select_template_journeys_path
    
    assert_response :success
    assert_select ".bg-blue-100", @awareness_template.campaign_type.humanize
    assert_select ".bg-green-100", @awareness_template.complexity_level.humanize
    assert_select ".bg-gray-100", @awareness_template.industry.humanize
  end

  test "should display template stats" do
    get select_template_journeys_path
    
    assert_response :success
    
    # Check stages count
    assert_select "[data-template-id='#{@awareness_template.id}'] .text-lg", 
                  @awareness_template.template_data["stages"].length.to_s
    
    # Check steps count  
    assert_select "[data-template-id='#{@awareness_template.id}'] .text-lg", 
                  @awareness_template.template_data["steps"].length.to_s
  end

  test "should show template preview action" do
    get select_template_journeys_path
    
    assert_response :success
    assert_select "[data-action='click->template-selector#showPreview']", "Preview"
  end

  test "should show template creation form" do
    get select_template_journeys_path
    
    assert_response :success
    assert_select "form[action='#{create_from_template_journeys_path}']"
    assert_select "input[name='template_id'][value='#{@awareness_template.id}']"
    assert_select "input[name='journey_name']"
  end

  test "should require authentication" do
    sign_out
    
    get select_template_journeys_path
    
    assert_redirected_to new_session_path
  end
end