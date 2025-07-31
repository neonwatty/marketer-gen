require "test_helper"

class FormValidationTest < ActionDispatch::IntegrationTest
  test "registration form has validation elements" do
    get sign_up_path
    assert_response :success
    
    # Check that the form has the validation controller attached
    assert_select "div[data-controller='form-validation']"
    assert_select "div[data-form-validation-mode-value='registration']"
    
    # Check that email field has validation targets and actions
    assert_select "input[data-form-validation-target='emailField']"
    assert_select "input[data-action*='form-validation#validateEmail']"
    
    # Check that password field has validation targets and actions
    assert_select "input[data-form-validation-target='passwordField']"
    assert_select "input[data-action*='form-validation#validatePassword']"
    
    # Check that password confirmation field has validation targets and actions
    assert_select "input[data-form-validation-target='passwordConfirmationField']"
    assert_select "input[data-action*='form-validation#validatePasswordConfirmation']"
    
    # Check that submit button has validation target
    assert_select "input[data-form-validation-target='submitButton']"
    
    # Check that error message containers exist
    assert_select "div[data-form-validation-target='emailError']"
    assert_select "div[data-form-validation-target='passwordError']"
    assert_select "div[data-form-validation-target='passwordConfirmationError']"
    assert_select "div[data-form-validation-target='passwordStrength']"
  end
  
  test "login form has validation elements" do
    get new_session_path
    assert_response :success
    
    # Check that the form has the validation controller attached
    assert_select "div[data-controller='form-validation']"
    assert_select "div[data-form-validation-mode-value='login']"
    
    # Check that email field has validation targets and actions
    assert_select "input[data-form-validation-target='emailField']"
    assert_select "input[data-action*='form-validation#validateEmail']"
    
    # Check that password field has validation targets and actions
    assert_select "input[data-form-validation-target='passwordField']"
    assert_select "input[data-action*='form-validation#validatePassword']"
    
    # Check that submit button has validation target
    assert_select "input[data-form-validation-target='submitButton']"
    
    # Check that error message containers exist
    assert_select "div[data-form-validation-target='emailError']"
    assert_select "div[data-form-validation-target='passwordError']"
    
    # Check that password strength is NOT present in login form
    assert_select "div[data-form-validation-target='passwordStrength']", false
    assert_select "div[data-form-validation-target='passwordConfirmationError']", false
  end
  
  test "form fields have proper CSS classes for validation states" do
    get sign_up_path
    assert_response :success
    
    # Check that fields have the border-gray-400 class initially
    assert_select "input.border-gray-400"
    
    # Check that fields have transition classes
    assert_select "input.transition-colors"
    
    # Check that submit button has disabled state classes
    assert_select "input.disabled\\:opacity-50"
    assert_select "input.disabled\\:cursor-not-allowed"
    
    # Check that error containers are initially hidden
    assert_select "div.hidden[data-form-validation-target='emailError']"
    assert_select "div.hidden[data-form-validation-target='passwordError']"
    assert_select "div.hidden[data-form-validation-target='passwordConfirmationError']"
    assert_select "div.hidden[data-form-validation-target='passwordStrength']"
  end
end