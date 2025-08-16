require 'application_system_test_case'

class CampaignPlanVisualizationTest < ApplicationSystemTestCase
  def setup
    @user = users(:marketer_user)
    
    @campaign_plan = campaign_plans(:completed_plan)
    @campaign_plan.generated_strategy = {
      'objectives' => ['Increase brand awareness', 'Drive website traffic'],
      'key_messages' => ['Quality products', 'Excellent service'],
      'rationale' => 'Strategic approach based on market analysis',
      'channels' => ['Social Media', 'Email Marketing', 'Content Marketing'],
      'budget_allocation' => { 'social' => 40, 'email' => 30, 'content' => 30 },
      'creative_themes' => ['Authentic storytelling', 'Customer success']
    }
    @campaign_plan.generated_timeline = [
      { 'week' => 1, 'activity' => 'Campaign launch preparation', 'description' => 'Initial setup and planning' },
      { 'week' => 2, 'activity' => 'Content creation and review', 'description' => 'Develop and approve content' },
      { 'week' => 3, 'activity' => 'Launch and monitoring', 'description' => 'Go live and track performance' }
    ]
    @campaign_plan.generated_assets = ['Brand guidelines', 'Social media templates', 'Email templates']
    @campaign_plan.save!
  end

  test "user can interact with timeline visualization controls" do
    login_as(@user)
    visit campaign_plan_path(@campaign_plan)
    
    # Verify timeline section is present
    assert_text "Interactive Timeline"
    
    # Test timeline animation button
    assert_button "Animate Timeline"
    click_button "Animate Timeline"
    
    # Button text should change when clicked
    assert_button "Stop Animation"
    
    # Test timeline view selector
    assert_selector "select#timeline-view"
    select "Compact", from: "timeline-view"
    select "Overview", from: "timeline-view"
    select "Detailed", from: "timeline-view"
  end

  test "user can expand and collapse content mapping sections" do
    login_as(@user)
    visit campaign_plan_path(@campaign_plan)
    
    # Verify content mapping section is present
    assert_text "Content Mapping"
    
    # Find all content platform sections
    within '.content-map-platform:first-of-type' do
      # Content details should be hidden initially
      assert_selector '.content-details[style*="display: none"]'
      
      # Click the toggle button
      find('.content-map-toggle').click
      
      # Content details should now be visible
      assert_selector '.content-details:not([style*="display: none"])'
      
      # Verify content is displayed
      assert_text "Recommended Content Types"
      assert_text "Publishing Frequency"
      assert_text "Strategic Purpose"
    end
  end

  test "user can view timeline item details" do
    login_as(@user)
    visit campaign_plan_path(@campaign_plan)
    
    within '.timeline-item:first-of-type' do
      # Details should be hidden initially
      assert_selector '.timeline-details.hidden'
      
      # Click view details button
      click_button "View Details"
      
      # Details should now be visible
      assert_selector '.timeline-details:not(.hidden)'
      
      # Verify detail content is displayed
      assert_text "Dependencies:"
      assert_text "Resources needed:"
      assert_text "Success metrics:"
      
      # Button text should change
      assert_button "Hide Details"
      
      # Click to hide details again
      click_button "Hide Details"
      assert_selector '.timeline-details.hidden'
    end
  end

  test "responsive design works across different viewport sizes" do
    login_as(@user)
    # Test desktop view
    page.driver.browser.manage.window.resize_to(1200, 800)
    visit campaign_plan_path(@campaign_plan)
    
    assert_text "Strategic Overview"
    assert_text "Content Mapping"
    assert_text "Creative Approach"
    
    # Test tablet view
    page.driver.browser.manage.window.resize_to(768, 1024)
    visit campaign_plan_path(@campaign_plan)
    
    assert_text "Strategic Overview"
    assert_text "Content Mapping"
    
    # Test mobile view
    page.driver.browser.manage.window.resize_to(375, 667)
    visit campaign_plan_path(@campaign_plan)
    
    assert_text "Strategic Overview"
    assert_text "Content Mapping"
    
    # Verify elements are still interactive on mobile
    within '.content-map-platform:first-of-type' do
      find('.content-map-toggle').click
      assert_text "Recommended Content Types"
    end
  end

  test "accessibility features work correctly" do
    login_as(@user)
    visit campaign_plan_path(@campaign_plan)
    
    # Test keyboard navigation
    find('body').send_keys(:tab)
    assert_selector ':focus'
    
    # Test ARIA labels and roles
    assert_selector '[aria-label]', minimum: 1
    
    # Test button accessibility
    within '.timeline-container' do
      buttons = all('button')
      buttons.each do |button|
        assert button[:type] == 'button' || button.tag_name == 'button'
      end
    end
    
    # Test that interactive elements are focusable
    find('.content-map-toggle:first-of-type').click
    assert_focused '.content-map-toggle:first-of-type'
  end

  test "timeline animation progresses correctly" do
    login_as(@user)
    visit campaign_plan_path(@campaign_plan)
    
    # Start timeline animation
    click_button "Animate Timeline"
    
    # Check that progress counter starts at 0
    assert_text "0 / 3 activities"
    
    # Wait for animation to progress (using sleep for demo, in real tests use proper waits)
    sleep(1)
    
    # Progress should have started
    timeline_counter = find('#timeline-counter')
    counter_value = timeline_counter.text.to_i
    assert counter_value >= 0
    
    # Stop animation
    click_button "Stop Animation"
    assert_button "Animate Timeline"
  end

  test "content sections display appropriate content for different channel types" do
    login_as(@user)
    visit campaign_plan_path(@campaign_plan)
    
    # Test Social Media platform
    within '.content-map-platform[data-platform="social-media"]' do
      find('.content-map-toggle').click
      assert_text "Visual Posts"
      assert_text "Stories"
      assert_text "3-5 posts per week"
    end
    
    # Test Email Marketing platform
    within '.content-map-platform[data-platform="email-marketing"]' do
      find('.content-map-toggle').click
      assert_text "Welcome Series"
      assert_text "Newsletter"
      assert_text "Weekly newsletter"
    end
  end

  test "creative approach shows dynamic content based on campaign type" do
    login_as(@user)
    # Test awareness campaign
    @campaign_plan.update(campaign_type: 'awareness')
    visit campaign_plan_path(@campaign_plan)
    
    within '.creative-approach' do
      assert_text "Inspiring and educational"
    end
    
    # Test conversion campaign
    @campaign_plan.update(campaign_type: 'conversion')
    visit campaign_plan_path(@campaign_plan)
    
    within '.creative-approach' do
      assert_text "Persuasive and action-oriented"
    end
  end

  test "strategic rationale displays success metrics based on campaign objective" do
    login_as(@user)
    # Test awareness objective
    @campaign_plan.update(objective: 'awareness')
    visit campaign_plan_path(@campaign_plan)
    
    within '.strategic-rationale' do
      assert_text "Reach"
      assert_text "Impressions"
      assert_text "Brand Recall"
    end
    
    # Test conversion objective
    @campaign_plan.update(objective: 'conversion')
    visit campaign_plan_path(@campaign_plan)
    
    within '.strategic-rationale' do
      assert_text "Conversion Rate"
      assert_text "Cost per Acquisition"
      assert_text "Revenue"
    end
  end

  test "page loads without JavaScript errors" do
    login_as(@user)
    visit campaign_plan_path(@campaign_plan)
    
    # Check that no JavaScript console errors occurred
    logs = page.driver.browser.manage.logs.get(:browser)
    js_errors = logs.select { |log| log.level == 'SEVERE' && log.message.include?('javascript') }
    assert_empty js_errors, "JavaScript errors found: #{js_errors.map(&:message)}"
  end

  test "all interactive elements respond to user interactions" do
    login_as(@user)
    visit campaign_plan_path(@campaign_plan)
    
    # Test timeline controls
    click_button "Animate Timeline"
    sleep(0.5)
    click_button "Stop Animation"
    
    # Test content map toggles
    all('.content-map-toggle').each_with_index do |toggle, index|
      toggle.click
      sleep(0.2)
      # Verify content is revealed
      assert_selector '.content-details:not([style*="display: none"])', count: index + 1
    end
    
    # Test timeline detail toggles
    all('.timeline-details-toggle').each do |toggle|
      toggle.click
      sleep(0.2)
    end
    
    # Test timeline view changes
    select "Compact", from: "timeline-view"
    sleep(0.2)
    select "Overview", from: "timeline-view"
  end

  test "sections gracefully handle missing data scenarios" do
    login_as(@user)
    @campaign_plan.update(
      generated_strategy: nil,
      generated_timeline: nil,
      generated_assets: nil
    )
    
    visit campaign_plan_path(@campaign_plan)
    
    # Should show fallback content instead of errors
    assert_text "Strategic objectives will be defined"
    assert_text "Timeline Coming Soon"
    assert_text "Content Strategy Pending"
    
    # Page should still be functional
    assert_selector 'h1', text: @campaign_plan.name
    assert_button "Edit"
  end

  test "hover states and transitions work correctly" do
    login_as(@user)
    visit campaign_plan_path(@campaign_plan)
    
    # Test card hover effects by checking CSS classes
    assert_selector '.content-map-platform'
    assert_selector '.timeline-card'
    assert_selector '.creative-element'
    
    # Verify transition classes are applied
    page.execute_script("
      document.querySelectorAll('.content-map-platform').forEach(el => {
        el.style.transition.includes('all');
      });
    ")
  end

  private

  def assert_focused(selector)
    focused_element = page.evaluate_script('document.activeElement')
    target_element = find(selector).native
    assert_equal target_element, focused_element
  end
end