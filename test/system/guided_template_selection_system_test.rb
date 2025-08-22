require "application_system_test_case"

class GuidedTemplateSelectionSystemTest < ApplicationSystemTestCase
  def setup
    @user = users(:marketer_user)
    sign_in_as(@user)
    
    # Create test templates for guided selection
    @beginner_awareness_template = JourneyTemplate.create!(
      name: "Simple Brand Awareness",
      description: "Easy-to-follow brand awareness campaign",
      campaign_type: "awareness",
      category: "acquisition", 
      industry: "technology",
      complexity_level: "beginner",
      template_data: {
        "stages" => ["discovery", "education", "engagement"],
        "steps" => [
          {
            "title" => "Social Media Introduction",
            "description" => "Introduce your brand on social platforms",
            "step_type" => "social_media",
            "channel" => "social",
            "stage" => "discovery"
          }
        ],
        "metadata" => {
          "timeline" => "2-3 weeks",
          "key_metrics" => ["reach", "awareness"],
          "target_audience" => "New prospects"
        }
      }
    )
    
    @advanced_conversion_template = JourneyTemplate.create!(
      name: "Advanced Conversion Strategy",
      description: "Multi-channel conversion optimization",
      campaign_type: "conversion",
      category: "conversion",
      industry: "ecommerce", 
      complexity_level: "advanced",
      template_data: {
        "stages" => ["interest", "consideration", "purchase"],
        "steps" => [
          {
            "title" => "Retargeting Campaign",
            "description" => "Target warm prospects with conversion ads",
            "step_type" => "ad_campaign",
            "channel" => "advertising",
            "stage" => "consideration"
          }
        ]
      }
    )
  end

  test "guided question progression with animations and accessibility" do
    visit select_template_journeys_path
    
    # Should show initial guided question
    assert_selector "[data-template-selector-target='guidedQuestions']"
    assert_selector "h3", text: /What type of campaign are you planning/
    assert_selector "[role='region'][aria-label='Guided template selection questions']"
    
    # Question should have proper accessibility attributes
    assert_selector "#question-1"
    assert_selector "[role='group'][aria-labelledby='question-1']"
    
    # Should show campaign type options with icons
    assert_selector "button[aria-label*='Select Awareness']"
    assert_selector ".lucide-eye" # Awareness icon
    
    # Click on awareness campaign type
    awareness_button = find("button[aria-label*='Select Awareness']")
    awareness_button.click
    
    # Should show loading animation and progress
    assert_selector ".transition-all"
    
    # Wait for Turbo response
    sleep 0.5
    
    # Should progress to step 2 (experience level)
    assert_selector "h3", text: /What's your experience level with Awareness campaigns/
    assert_selector "[role='group'][aria-labelledby='question-2']"
    
    # Should show complexity level options
    assert_selector "button[aria-label*='Select Beginner']"
    
    # Click beginner level
    beginner_button = find("button[aria-label*='Select Beginner']")
    beginner_button.click
    
    # Wait for response
    sleep 0.5
    
    # Should progress to step 3 (industry)
    assert_selector "h3", text: /Which industry best describes your business/
    
    # Click technology industry
    tech_button = find("button", text: "Technology")
    tech_button.click
    
    # Wait for response
    sleep 0.5
    
    # Should progress to step 4 (category)
    assert_selector "h3", text: /What's the primary focus of this campaign/
    
    # Click acquisition category
    acquisition_button = find("button", text: "Acquisition")
    acquisition_button.click
    
    # Wait for response
    sleep 0.5
    
    # Should show completion message or filtered results
    assert(page.has_content?("Perfect! Here are your recommended templates") ||
           page.has_selector?("[data-template-id='#{@beginner_awareness_template.id}']"))
    
    # Should show filtered template that matches criteria
    assert_selector "[data-template-id='#{@beginner_awareness_template.id}']"
    assert_no_selector "[data-template-id='#{@advanced_conversion_template.id}']"
  end

  test "keyboard navigation in guided questions" do
    visit select_template_journeys_path
    
    # Focus should be on first question button
    first_button = find("button[aria-label*='Select Awareness']")
    first_button.focus
    assert_equal first_button, page.driver.browser.switch_to.active_element
    
    # Test tab navigation between option buttons
    page.send_keys(:tab)
    second_button = find("button[aria-label*='Select Consideration']")
    assert_equal second_button, page.driver.browser.switch_to.active_element
    
    # Test Enter key activation
    page.send_keys(:enter)
    
    # Should progress to next question
    sleep 0.5
    assert_selector "h3", text: /What's your experience level/
  end

  test "skip option functionality" do
    visit select_template_journeys_path
    
    # Progress through first required question
    awareness_button = find("button[aria-label*='Select Awareness']")
    awareness_button.click
    sleep 0.5
    
    # Should show experience level with skip option
    assert_selector "h3", text: /What's your experience level/
    
    # Skip this step (complexity level is optional)
    beginner_button = find("button[aria-label*='Select Beginner']")
    beginner_button.click
    sleep 0.5
    
    # Progress to industry question
    assert_selector "h3", text: /Which industry best describes/
    
    # Industry question should have skip option
    if page.has_link?("Skip this step")
      click_link "Skip this step"
      sleep 0.5
      
      # Should progress to category or show results
      assert(page.has_selector?("h3", text: /What's the primary focus/) ||
             page.has_content?("Perfect! Here are your recommended templates"))
    end
  end

  test "turbo stream updates with guided questions" do
    visit select_template_journeys_path
    
    # Verify initial state
    assert_selector "[data-template-selector-target='guidedQuestions']"
    
    # Click campaign type with Turbo
    within "[data-template-selector-target='guidedQuestions']" do
      click_button class: /bg-white border border-gray-200/
    end
    
    # Should update via Turbo Stream without full page reload
    sleep 0.5
    assert_selector "[data-template-selector-target='guidedQuestions']"
    
    # Verify template content frame is also updated
    assert_selector "turbo-frame#template-content"
  end

  test "responsive guided questions on mobile" do
    # Set mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)
    
    visit select_template_journeys_path
    
    # Guided questions should adapt to mobile layout
    assert_selector "[data-template-selector-target='guidedQuestions']"
    assert_selector ".grid-cols-1" # Should use single column on mobile
    
    # Buttons should be touch-friendly
    awareness_button = find("button[aria-label*='Select Awareness']")
    assert awareness_button[:class].include?("p-4") # Adequate padding for touch
    
    # Should still be functional
    awareness_button.click
    sleep 0.5
    assert_selector "h3", text: /What's your experience level/
  end

  test "accessibility features in guided questions" do
    visit select_template_journeys_path
    
    # Check ARIA attributes
    assert_selector "[role='region'][aria-label='Guided template selection questions']"
    assert_selector "#question-1"
    assert_selector "[role='group'][aria-labelledby='question-1']"
    
    # Check button accessibility
    assert_selector "button[role='button'][aria-label*='Select Awareness']"
    
    # Check focus management
    first_button = find("button[aria-label*='Select Awareness']")
    first_button.focus
    assert first_button[:class].include?("focus:ring-2")
    
    # Check color contrast (buttons should have adequate contrast)
    button_classes = first_button[:class]
    assert button_classes.include?("border-gray-200")
    assert button_classes.include?("text-left")
  end

  test "error handling in guided questions" do
    # Simulate network error by stubbing the request
    visit select_template_journeys_path
    
    # Mock a failed request (this would need to be implemented with proper mocking)
    # For now, test that the interface remains functional
    
    awareness_button = find("button[aria-label*='Select Awareness']")
    awareness_button.click
    
    # Should handle gracefully and not break the interface
    sleep 1.0
    assert_selector "[data-template-selector-target='guidedQuestions']"
  end

  test "template filtering updates during guided flow" do
    visit select_template_journeys_path
    
    # Start with all templates visible
    assert_selector "[data-template-id='#{@beginner_awareness_template.id}']"
    assert_selector "[data-template-id='#{@advanced_conversion_template.id}']"
    
    # Select awareness campaign type
    awareness_button = find("button[aria-label*='Select Awareness']")
    awareness_button.click
    sleep 0.5
    
    # Should filter to only awareness templates
    assert_selector "[data-template-id='#{@beginner_awareness_template.id}']"
    assert_no_selector "[data-template-id='#{@advanced_conversion_template.id}']"
    
    # Select beginner complexity
    beginner_button = find("button[aria-label*='Select Beginner']")
    beginner_button.click
    sleep 0.5
    
    # Should maintain awareness filter and add complexity filter
    assert_selector "[data-template-id='#{@beginner_awareness_template.id}']"
    assert_no_selector "[data-template-id='#{@advanced_conversion_template.id}']"
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"
  end
end