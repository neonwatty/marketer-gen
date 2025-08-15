require "application_system_test_case"

class JourneySuggestionsSystemTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
  end

  test "suggestions section is present on journey show page" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    # Wait for page to load
    assert_text @journey.name
    
    # Verify suggestions section exists
    assert_selector '[data-controller="journey-suggestions"]'
    assert_selector '[data-journey-suggestions-target="suggestionsContainer"]'
    assert_selector 'h3', text: 'AI-Powered Step Suggestions'
  end

  test "stage selector is present when journey has stages" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    # Should show stage selector if journey has stages
    if @journey.stages&.any?
      assert_selector 'select[data-journey-suggestions-target="stageSelect"]'
      assert_selector 'label', text: 'Stage:'
      
      # Should have options for each stage
      @journey.stages.each do |stage|
        assert_selector 'option', text: stage.humanize
      end
    end
  end

  test "refresh button is present and clickable" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    assert_selector 'button[data-journey-suggestions-target="refreshButton"]'
    assert_selector 'button', text: 'Refresh'
    
    # Button should be clickable
    refresh_button = find('button[data-journey-suggestions-target="refreshButton"]')
    assert_not refresh_button[:disabled]
  end

  test "loading spinner is initially hidden" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    # Loading spinner should be hidden initially
    assert_selector '[data-journey-suggestions-target="loadingSpinner"].hidden'
  end

  test "suggestions container is present for content" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    assert_text @journey.name
    assert_selector '[data-journey-suggestions-target="suggestionsContainer"]'
  end

  test "page layout includes all required elements" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    # Wait for page to load
    assert_text @journey.name
    
    # Verify overall page structure
    assert_selector 'h1', text: @journey.name
    assert_selector '[data-controller="journey-suggestions"]'
    assert_selector '[data-controller="journey-builder"]'
    
    # Verify suggestions section is positioned correctly
    suggestions_section = find('[data-controller="journey-suggestions"]')
    journey_steps_section = find('h3', text: 'Journey Steps').ancestor('div.bg-white')
    
    # Suggestions should appear before journey steps
    assert_operator suggestions_section.native.location['y'], :<, journey_steps_section.native.location['y']
  end

  test "journey without stages doesn't show stage selector" do
    sign_in_as(@user)
    
    # Create journey without stages
    journey_no_stages = @user.journeys.create!(
      name: "No Stages Journey",
      campaign_type: "awareness",
      status: "draft"
    )
    journey_no_stages.update_column(:stages, nil)
    
    visit journey_path(journey_no_stages)
    
    # Should not show stage selector
    assert_no_selector 'select[data-journey-suggestions-target="stageSelect"]'
    assert_no_selector 'label', text: 'Stage:'
  end

  test "data attributes are correctly set" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    # Wait for page to load
    assert_text @journey.name
    
    suggestions_element = find('[data-controller="journey-suggestions"]')
    
    # Verify data attributes
    assert_equal @journey.id.to_s, suggestions_element['data-journey-suggestions-journey-id-value']
    
    if @journey.stages&.any?
      assert_equal @journey.stages.first, suggestions_element['data-journey-suggestions-current-stage-value']
    end
  end

  test "refresh button has correct styling" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    refresh_button = find('button[data-journey-suggestions-target="refreshButton"]')
    
    # Verify button has blue styling (Tailwind classes)
    button_classes = refresh_button[:class]
    assert_includes button_classes, 'bg-blue-600'
    assert_includes button_classes, 'text-white'
  end

  test "suggestions section has proper accessibility attributes" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    # Check for proper labeling
    if has_selector?('select[data-journey-suggestions-target="stageSelect"]')
      stage_select = find('select[data-journey-suggestions-target="stageSelect"]')
      assert_equal 'stage-select', stage_select[:id]
      
      label = find('label[for="stage-select"]')
      assert_equal 'Stage:', label.text
    end
    
    # Verify heading hierarchy
    assert_selector 'h3', text: 'AI-Powered Step Suggestions'
  end

  test "page is responsive and mobile friendly" do
    sign_in_as(@user)
    
    # Test with different viewport sizes
    page.driver.browser.manage.window.resize_to(320, 568) # Mobile
    visit journey_path(@journey)
    
    # Should still show suggestions section
    assert_selector '[data-controller="journey-suggestions"]'
    
    # Reset to desktop size
    page.driver.browser.manage.window.resize_to(1024, 768)
    visit journey_path(@journey)
    
    assert_selector '[data-controller="journey-suggestions"]'
  end

  test "multiple journeys have independent suggestion sections" do
    sign_in_as(@user)
    
    # Create another journey
    other_journey = @user.journeys.create!(
      name: "Other Journey",
      campaign_type: "conversion",
      status: "draft"
    )
    
    # Visit first journey
    visit journey_path(@journey)
    first_suggestions = find('[data-controller="journey-suggestions"]')
    first_journey_id = first_suggestions['data-journey-suggestions-journey-id-value']
    
    # Visit second journey
    visit journey_path(other_journey)
    second_suggestions = find('[data-controller="journey-suggestions"]')
    second_journey_id = second_suggestions['data-journey-suggestions-journey-id-value']
    
    # Should have different journey IDs
    assert_not_equal first_journey_id, second_journey_id
    assert_equal @journey.id.to_s, first_journey_id
    assert_equal other_journey.id.to_s, second_journey_id
  end

  test "suggestions section integrates well with existing journey builder" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    # Both controllers should be present
    assert_selector '[data-controller="journey-suggestions"]'
    assert_selector '[data-controller="journey-builder"]'
    
    # Should not interfere with existing drag and drop functionality
    if has_selector?('[data-journey-builder-target="step"]')
      step_element = find('[data-journey-builder-target="step"]')
      assert step_element[:draggable]
    end
  end

  test "journey show page maintains proper semantic structure" do
    sign_in_as(@user)
    visit journey_path(@journey)
    
    # Verify semantic HTML structure
    assert_selector 'main, [role="main"]'
    
    # Headings should be in proper hierarchy
    page_title = find('h1')
    section_headings = all('h2, h3')
    
    section_headings.each do |heading|
      # All section headings should come after the main title
      assert_operator page_title.native.location['y'], :<, heading.native.location['y']
    end
  end

  # Note: JavaScript-dependent tests would require additional setup
  # These would test actual AJAX functionality, loading states, etc.
  # For now, we're testing the static HTML structure and basic accessibility

  private

  def sign_in_as(user)
    visit new_session_path
    
    # Use placeholder text instead of field name
    fill_in placeholder: 'Enter your email address', with: user.email_address
    fill_in placeholder: 'Enter your password', with: 'password'
    click_button 'Sign in'
    
    # Ensure we're redirected away from login page
    assert_no_text 'Sign in', wait: 5
  end
end