require "application_system_test_case"

class DemoTourTest < ApplicationSystemTestCase
  
  def setup
    @user = users(:marketer_user)
  end

  test "demo button should be visible in navigation" do
    visit root_path
    
    within("nav") do
      assert_selector "button", text: "Demo"
    end
  end

  test "demo button should start tour on homepage" do
    visit root_path
    
    # Click the demo button
    within("nav") do
      click_button "Demo"
    end
    
    # Check that intro.js tour has started
    assert_selector ".introjs-tooltip", wait: 5
    assert_text "Welcome to Marketer Gen!"
  end

  test "demo tour should work when logged in" do
    sign_in_as(@user)
    visit root_path
    
    # Click the demo button
    within("nav") do
      click_button "Demo"
    end
    
    # Check that tour started
    assert_selector ".introjs-tooltip", wait: 5
    
    # Check for navigation elements in tour
    assert_selector ".introjs-bullets"
    assert_selector "a.introjs-button.introjs-nextbutton", text: "Next →"
    assert_selector "a.introjs-button.introjs-skipbutton", text: "Skip"
  end

  test "demo tour should show different content on different pages" do
    sign_in_as(@user)
    
    # Test on campaign plans page
    visit campaign_plans_path
    
    within("nav") do
      click_button "Demo"
    end
    
    assert_selector ".introjs-tooltip", wait: 5
    assert_text "Campaign Plans"
  end

  test "demo tour should be skippable" do
    visit root_path
    
    within("nav") do
      click_button "Demo"
    end
    
    # Wait for tour to start
    assert_selector ".introjs-tooltip", wait: 5
    
    # Click skip button
    click_link "Skip"
    
    # Tour should be closed
    assert_no_selector ".introjs-tooltip"
  end

  test "demo tour should navigate through steps" do
    visit root_path
    
    within("nav") do
      click_button "Demo"
    end
    
    # Wait for tour to start
    assert_selector ".introjs-tooltip", wait: 5
    
    # Check initial step
    assert_text "Welcome to Marketer Gen!"
    
    # Click next
    click_link "Next →"
    
    # Should move to next step
    assert_text "main navigation bar"
    
    # Click back
    click_link "← Back"
    
    # Should go back to first step
    assert_text "Welcome to Marketer Gen!"
  end

  test "demo tour should complete successfully" do
    visit root_path
    
    within("nav") do
      click_button "Demo"
    end
    
    # Wait for tour to start
    assert_selector ".introjs-tooltip", wait: 5
    
    # Navigate through all steps (7 steps total based on getDashboardTourSteps)
    6.times do
      click_link "Next →"
      sleep 0.2 # Small delay between steps
    end
    
    # Should see finish button on last step
    assert_selector "a.introjs-button", text: "Finish Tour"
    
    # Click finish
    click_link "Finish Tour"
    
    # Tour should be closed
    assert_no_selector ".introjs-tooltip"
    
    # Should see completion message
    assert_selector ".fixed", text: "Tour Complete!"
  end

  test "demo tour should handle page navigation correctly" do
    sign_in_as(@user)
    visit journeys_path
    
    within("nav") do
      click_button "Demo"
    end
    
    # Should show journey-specific tour
    assert_selector ".introjs-tooltip", wait: 5
    assert_text "Customer Journeys"
  end

  test "demo tour should work on mobile viewport" do
    # Set mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)
    
    visit root_path
    
    # Demo button should still be visible (icon only on mobile)
    within("nav") do
      assert_selector "button[data-controller='demo']"
    end
    
    # Reset viewport
    page.driver.browser.manage.window.resize_to(1024, 768)
  end
end