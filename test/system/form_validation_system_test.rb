require "application_system_test_case"

class FormValidationSystemTest < ApplicationSystemTestCase
  test "registration form shows email validation errors" do
    visit sign_up_path
    
    # Fill in invalid email
    fill_in "Email address", with: "invalid-email"
    
    # Trigger blur event by clicking somewhere else
    click_on "Password"
    
    # Check that error message appears (using a wait since it's JavaScript)
    assert_text "Please enter a valid email address", wait: 2
    
    # Check that field has error styling
    assert_selector "input[data-form-validation-target='emailField'].border-red-500"
  end
  
  test "registration form shows password strength indicator" do
    visit sign_up_path
    
    # Fill in weak password
    fill_in "Password", with: "123"
    
    # Wait for strength indicator to appear
    assert_text "Weak", wait: 2
    
    # Fill in medium strength password
    fill_in "Password", with: "password123"
    
    # Wait for strength indicator to change
    assert_text "Medium", wait: 2
    
    # Fill in strong password
    fill_in "Password", with: "StrongPass123!"
    
    # Wait for strength indicator to change
    assert_text "Strong", wait: 2
  end
  
  test "registration form validates password confirmation" do
    visit sign_up_path
    
    # Fill in password
    fill_in "Password", with: "password123"
    
    # Fill in mismatched confirmation
    fill_in "Password confirmation", with: "different123"
    
    # Trigger validation by clicking elsewhere
    click_on "Email address"
    
    # Check that error message appears
    assert_text "Passwords do not match", wait: 2
    
    # Check that field has error styling
    assert_selector "input[data-form-validation-target='passwordConfirmationField'].border-red-500"
  end
  
  test "registration form enables submit button when valid" do
    visit sign_up_path
    
    # Initially submit button should be disabled
    assert_selector "input[data-form-validation-target='submitButton'][disabled]"
    
    # Fill in valid form data
    fill_in "Email address", with: "test@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    
    # Wait for validation to complete and submit button to be enabled
    assert_no_selector "input[data-form-validation-target='submitButton'][disabled]", wait: 2
  end
  
  test "login form validates email and password" do
    visit new_session_path
    
    # Initially submit button should be disabled
    assert_selector "input[data-form-validation-target='submitButton'][disabled]"
    
    # Fill in invalid email
    fill_in "Email address", with: "invalid-email"
    click_on "Password"
    
    # Check that error message appears
    assert_text "Please enter a valid email address", wait: 2
    
    # Fill in valid email and short password
    fill_in "Email address", with: "test@example.com"
    fill_in "Password", with: "123"
    click_on "Email address"
    
    # Check password error
    assert_text "Password must be at least 6 characters", wait: 2
    
    # Fill in valid password
    fill_in "Password", with: "password123"
    
    # Submit button should now be enabled
    assert_no_selector "input[data-form-validation-target='submitButton'][disabled]", wait: 2
  end
  
  test "login form does not show password strength indicator" do
    visit new_session_path
    
    # Fill in password
    fill_in "Password", with: "password123"
    
    # Should not see strength indicator
    assert_no_text "Weak"
    assert_no_text "Medium"
    assert_no_text "Strong"
  end
end