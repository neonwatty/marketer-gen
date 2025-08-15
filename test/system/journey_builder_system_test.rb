require "application_system_test_case"

class JourneyBuilderSystemTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    sign_in_as(@user)
  end

  test "journey form shows stages when campaign type changes" do
    visit new_journey_path

    # Initially no stages should be visible
    assert_no_selector "[data-journey-form-target='stagesPreview'] .bg-gray-50"

    # Select awareness campaign type
    select "Awareness", from: "journey[campaign_type]"

    # Should show awareness stages
    within "[data-journey-form-target='stagesPreview']" do
      assert_text "Discovery"
      assert_text "Education" 
      assert_text "Engagement"
    end

    # Change to conversion campaign type
    select "Conversion", from: "journey[campaign_type]"

    # Should show conversion stages
    within "[data-journey-form-target='stagesPreview']" do
      assert_text "Decision"
      assert_text "Purchase"
      assert_text "Onboarding"
    end

    # Change to consideration campaign type
    select "Consideration", from: "journey[campaign_type]"

    # Should show consideration stages
    within "[data-journey-form-target='stagesPreview']" do
      assert_text "Research"
      assert_text "Evaluation"
      assert_text "Comparison"
    end
  end

  test "journey step form advanced settings toggle" do
    journey = @user.journeys.create!(
      name: "Test Journey",
      campaign_type: "awareness",
      status: "draft"
    )

    visit new_journey_journey_step_path(journey)

    # Advanced settings should be hidden initially
    assert_selector "[data-journey-step-form-target='settingsContent'].hidden"

    # Click to expand advanced settings
    click_button "Advanced Settings"

    # Settings should now be visible
    assert_no_selector "[data-journey-step-form-target='settingsContent'].hidden"
    assert_text "Additional step-specific configuration"

    # Click again to collapse
    click_button "Advanced Settings"

    # Should be hidden again
    assert_selector "[data-journey-step-form-target='settingsContent'].hidden"
  end

  test "drag and drop step reordering" do
    journey = @user.journeys.create!(
      name: "Reorder Test Journey",
      campaign_type: "awareness",
      status: "draft"
    )

    # Create steps
    step1 = journey.journey_steps.create!(title: "First Step", step_type: "email", sequence_order: 0)
    step2 = journey.journey_steps.create!(title: "Second Step", step_type: "email", sequence_order: 1)
    step3 = journey.journey_steps.create!(title: "Third Step", step_type: "email", sequence_order: 2)

    visit journey_path(journey)

    # Verify initial order
    step_elements = all("[data-journey-builder-target='step']")
    assert_equal 3, step_elements.count
    
    first_step_title = step_elements[0].find("h4").text
    second_step_title = step_elements[1].find("h4").text
    third_step_title = step_elements[2].find("h4").text
    
    assert_equal "First Step", first_step_title
    assert_equal "Second Step", second_step_title  
    assert_equal "Third Step", third_step_title

    # Simulate drag and drop (move third step to first position)
    # Note: This is a simplified test - real drag/drop testing would require
    # more sophisticated setup with Selenium or similar
    page.execute_script("
      const steps = document.querySelectorAll('[data-journey-builder-target=\"step\"]');
      const controller = document.querySelector('[data-controller~=\"journey-builder\"]');
      if (controller && controller.application) {
        const controllerInstance = controller.application.getControllerForElementAndIdentifier(controller, 'journey-builder');
        if (controllerInstance) {
          controllerInstance.updateStepOrder();
        }
      }
    ")

    # For a real implementation, you would test actual drag and drop behavior
    # This is a placeholder to show the testing approach
  end

  test "journey filtering interface" do
    # Create test journeys
    awareness_journey = @user.journeys.create!(
      name: "Awareness Campaign",
      campaign_type: "awareness",
      template_type: "email",
      status: "active"
    )

    conversion_journey = @user.journeys.create!(
      name: "Conversion Campaign",
      campaign_type: "conversion", 
      template_type: "webinar",
      status: "draft"
    )

    visit journeys_path

    # Both journeys should be visible initially
    assert_text "Awareness Campaign"
    assert_text "Conversion Campaign"

    # Filter by campaign type
    select "Awareness", from: "campaign_type"
    click_button "Apply Filters"

    # Only awareness journey should be visible
    assert_text "Awareness Campaign"
    assert_no_text "Conversion Campaign"

    # Clear filters
    click_link "Clear"

    # Both should be visible again
    assert_text "Awareness Campaign" 
    assert_text "Conversion Campaign"

    # Filter by status
    select "Active", from: "status"
    click_button "Apply Filters"

    # Only active journey should be visible
    assert_text "Awareness Campaign"
    assert_no_text "Conversion Campaign"
  end

  test "journey creation end-to-end with JavaScript interactions" do
    visit new_journey_path

    # Fill in basic information
    fill_in "journey[name]", with: "Complete System Test Journey"
    fill_in "journey[description]", with: "Testing the complete workflow"
    fill_in "journey[target_audience]", with: "Test users"

    # Select campaign type and verify stages appear
    select "Awareness", from: "journey[campaign_type]"
    
    # Verify stages preview updates
    within "[data-journey-form-target='stagesPreview']" do
      assert_text "Discovery"
      assert_text "Education"
      assert_text "Engagement"
    end

    select "Email", from: "journey[template_type]"
    select "Draft", from: "journey[status]"

    # Submit form
    click_button "Create Journey"

    # Should be redirected to journey show page
    assert_current_path journey_path(Journey.last)
    assert_text "Complete System Test Journey"
    assert_text "Journey was successfully created"

    # Verify journey stages are displayed
    within(".bg-white") do
      assert_text "Discovery"
      assert_text "Education" 
      assert_text "Engagement"
    end

    # Add a step
    click_link "Add Step"
    
    fill_in "journey_step[title]", with: "Welcome Email Step"
    fill_in "journey_step[description]", with: "Send welcome email to new users"
    select "Email", from: "journey_step[step_type]"
    select "Email", from: "journey_step[channel]"

    # Test advanced settings toggle
    click_button "Advanced Settings"
    assert_text "Additional step-specific configuration"

    click_button "Create Step"

    # Should be back on journey show page with new step
    assert_text "Welcome Email Step"
    assert_text "Journey step was successfully created"
  end

  test "responsive design behavior" do
    visit journeys_path

    # Test mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667) # iPhone size

    # Navigation and layout should still be functional
    assert_selector "h1", text: "Customer Journeys"
    assert_selector ".grid" # Grid layout should adapt

    # Test desktop viewport  
    page.driver.browser.manage.window.resize_to(1920, 1080)

    # Should show full desktop layout
    assert_selector "h1", text: "Customer Journeys"
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign In"
  end
end