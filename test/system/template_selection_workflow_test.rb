# frozen_string_literal: true

require "application_system_test_case"

class TemplateSelectionWorkflowTest < ApplicationSystemTestCase
  def setup
    @user = users(:marketer_user)
    sign_in_as @user
    
    # Create test templates for different scenarios
    @beginner_template = JourneyTemplate.create!(
      name: "Simple Email Campaign",
      description: "Basic email marketing for beginners",
      campaign_type: "awareness",
      category: "acquisition",
      industry: "general",
      complexity_level: "beginner",
      template_data: {
        "stages" => ["awareness", "interest"],
        "steps" => [
          {
            "title" => "Welcome Email",
            "description" => "Send welcome message to new subscribers",
            "step_type" => "email",
            "channel" => "email",
            "stage" => "awareness"
          }
        ],
        "metadata" => {
          "timeline" => "1-2 weeks",
          "key_metrics" => ["open_rate", "click_rate"],
          "target_audience" => "New subscribers"
        }
      }
    )

    @advanced_template = JourneyTemplate.create!(
      name: "Multi-Channel Conversion",
      description: "Advanced conversion optimization with multiple touchpoints",
      campaign_type: "conversion", 
      category: "conversion",
      industry: "saas",
      complexity_level: "advanced",
      template_data: {
        "stages" => ["awareness", "interest", "consideration", "conversion"],
        "steps" => [
          {
            "title" => "Retargeting Ad Campaign",
            "description" => "Target visitors who viewed pricing page",
            "step_type" => "advertisement",
            "channel" => "paid_social",
            "stage" => "consideration"
          },
          {
            "title" => "Sales Follow-up Email",
            "description" => "Personalized follow-up from sales team",
            "step_type" => "email",
            "channel" => "email", 
            "stage" => "conversion"
          }
        ],
        "metadata" => {
          "timeline" => "4-6 weeks",
          "key_metrics" => ["conversion_rate", "pipeline_value", "roi"],
          "target_audience" => "Qualified leads"
        }
      }
    )
  end

  test "complete guided template selection workflow" do
    visit journeys_path
    
    # Click "Use Template" button
    click_button "Use Template"
    
    assert_current_path select_template_journeys_path
    assert_text "Choose a Journey Template"
    assert_text "What type of campaign are you planning?"
    
    # Step 1: Select campaign type
    click_button "Awareness"
    
    # Should advance to experience level question
    assert_text "What's your experience level with Awareness campaigns?"
    
    # Step 2: Select experience level
    click_button "Beginner"
    
    # Should advance to industry question
    assert_text "Which industry best describes your business?"
    
    # Step 3: Select industry  
    click_button "General"
    
    # Should advance to category question
    assert_text "What's the primary focus of this campaign?"
    
    # Step 4: Select category
    click_button "Acquisition"
    
    # Should show completion message and filtered templates
    assert_text "Perfect! Here are your recommended templates"
    assert_text @beginner_template.name
    assert_no_text @advanced_template.name # Should be filtered out
  end

  test "filter templates using sidebar" do
    visit select_template_journeys_path
    
    # Use sidebar filters instead of guided questions
    select "Conversion", from: "Campaign Type"
    
    # Should filter to show only conversion templates
    assert_text @advanced_template.name
    assert_no_text @beginner_template.name
    
    # Add complexity filter
    select "Advanced", from: "Experience Level"
    
    # Should still show advanced template
    assert_text @advanced_template.name
    
    # Change to beginner - should show no results
    select "Beginner", from: "Experience Level"
    
    assert_text "No templates found"
    assert_text "Try adjusting your filters"
  end

  test "search templates by name" do
    visit select_template_journeys_path
    
    # Search for specific template
    fill_in "Search templates", with: "Simple Email"
    
    # Should show matching template
    assert_text @beginner_template.name
    assert_no_text @advanced_template.name
    
    # Search for non-existent template
    fill_in "Search templates", with: "Non-existent Template"
    
    assert_text "No templates found"
  end

  test "preview template before using" do
    visit select_template_journeys_path
    
    # Click preview button
    within "[data-template-id='#{@beginner_template.id}']" do
      click_button "Preview"
    end
    
    # Should open preview modal
    assert_text "Template Preview"
    assert_text @beginner_template.name
    assert_text @beginner_template.description
    
    # Should show template details
    assert_text "Journey Stages"
    assert_text "Sample Steps"
    assert_text "Welcome Email"
    
    # Close preview
    click_button "Close"
    
    # Modal should be hidden
    assert_no_text "Template Preview"
  end

  test "create journey from template with default settings" do
    visit select_template_journeys_path
    
    # Use a template with default name
    within "[data-template-id='#{@beginner_template.id}']" do
      click_button "Use This Template"
    end
    
    # Should redirect to edit journey page
    assert_current_path edit_journey_path(Journey.last)
    assert_text "Journey created from template"
    
    # Verify journey was created correctly
    journey = Journey.last
    assert_equal "#{@beginner_template.name} Journey", journey.name
    assert_equal @beginner_template.description, journey.description
    assert_equal @beginner_template.campaign_type, journey.campaign_type
    
    # Verify journey steps were created
    assert_equal 1, journey.journey_steps.count
    step = journey.journey_steps.first
    assert_equal "Welcome Email", step.title
  end

  test "create journey from template with custom name" do
    visit select_template_journeys_path
    
    # Customize journey name before creating
    within "[data-template-id='#{@beginner_template.id}']" do
      fill_in "journey_name", with: "My Custom Email Campaign"
      click_button "Use This Template"
    end
    
    # Should create journey with custom name
    journey = Journey.last
    assert_equal "My Custom Email Campaign", journey.name
  end

  test "keyboard navigation works for template cards" do
    visit select_template_journeys_path
    
    # Focus on first template card
    find("[data-template-id='#{@beginner_template.id}']").send_keys(:tab)
    
    # Should be able to navigate with arrow keys
    page.driver.browser.action.send_keys(:arrow_down).perform
    
    # Should be able to activate preview with Enter
    page.driver.browser.action.send_keys(:enter).perform
    
    assert_text "Template Preview"
  end

  test "clear all filters functionality" do
    visit select_template_journeys_path
    
    # Apply some filters
    select "Conversion", from: "Campaign Type"
    select "Advanced", from: "Experience Level"
    
    # Verify filters are applied
    assert_text @advanced_template.name
    assert_no_text @beginner_template.name
    
    # Clear all filters
    click_link "Clear all filters"
    
    # Should show all templates again
    assert_text @beginner_template.name
    assert_text @advanced_template.name
  end

  test "template analytics display correctly" do
    visit select_template_journeys_path
    
    # Should show total template count
    assert_text "2 templates found"
    
    # Apply filter and check updated count
    select "Awareness", from: "Campaign Type"
    
    assert_text "1 template found"
  end

  test "responsive design works on mobile viewport" do
    # Test mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)
    
    visit select_template_journeys_path
    
    # Should still show all key elements
    assert_text "Choose a Journey Template"
    assert_text @beginner_template.name
    
    # Guided questions should work
    assert_text "What type of campaign are you planning?"
    click_button "Awareness"
    
    assert_text "What's your experience level"
  end

  test "error handling for failed template creation" do
    # Mock failure by making template invalid
    @beginner_template.update_column(:template_data, {})
    
    visit select_template_journeys_path
    
    within "[data-template-id='#{@beginner_template.id}']" do
      click_button "Use This Template"
    end
    
    # Should handle error gracefully
    assert_current_path select_template_journeys_path
    assert_text "Failed to create journey"
  end

  test "skip guided questions workflow" do
    visit select_template_journeys_path
    
    # Should see first guided question
    assert_text "What type of campaign are you planning?"
    
    # Skip to direct template browsing using sidebar
    select "All Types", from: "Campaign Type"
    
    # Should show all templates without guided questions
    assert_text @beginner_template.name
    assert_text @advanced_template.name
  end

  test "template metadata displays correctly" do
    visit select_template_journeys_path
    
    within "[data-template-id='#{@beginner_template.id}']" do
      # Should show campaign type badge
      assert_text "Awareness"
      
      # Should show complexity level badge  
      assert_text "Beginner"
      
      # Should show industry badge
      assert_text "General"
      
      # Should show template stats
      assert_text "2" # stages count
      assert_text "1" # steps count
      assert_text "1-2 weeks" # timeline
    end
  end

  test "integration with existing journey workflow" do
    visit journeys_path
    
    # Should have both options
    assert_button "Use Template"
    assert_button "New Journey"
    
    # Test that template creation integrates with journey management
    click_button "Use Template"
    
    within "[data-template-id='#{@beginner_template.id}']" do
      click_button "Use This Template"
    end
    
    # Should be in journey edit mode
    assert_current_path edit_journey_path(Journey.last)
    
    # Should be able to return to journeys list
    visit journeys_path
    
    # Created journey should appear in list
    assert_text "#{@beginner_template.name} Journey"
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "secret123456"
    click_button "Sign in"
  end
end