require "test_helper"

class PasswordResetFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "user@example.com",
      password: "oldpassword123",
      role: :marketer
    )
  end
  
  test "complete password reset flow" do
    # 1. User visits login page
    get new_session_path
    assert_response :success
    
    # 2. User clicks "Forgot password?" link (when we add it)
    get new_password_path
    assert_response :success
    assert_select "h1", "Forgot your password?"
    
    # 3. User submits email address
    assert_emails 1 do
      post passwords_path, params: { email_address: @user.email_address }
    end
    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "#notice", "Password reset instructions sent (if user with that email address exists)."
    
    # 4. User receives email with reset link
    email = ActionMailer::Base.deliveries.last
    assert_equal [@user.email_address], email.to
    assert_equal "Reset your password", email.subject
    
    # Extract token from email body
    token = @user.password_reset_token
    email_body = email.text_part ? email.text_part.body.to_s : email.body.to_s
    assert_match %r{passwords/[^/]+/edit}, email_body
    
    # 5. User clicks reset link in email
    get edit_password_path(token)
    assert_response :success
    assert_select "h1", "Update your password"
    
    # 6. User enters new password
    put password_path(token), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }
    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "#notice", "Password has been reset."
    
    # 7. User can login with new password
    post session_path, params: {
      email_address: @user.email_address,
      password: "newpassword123"
    }
    assert_redirected_to root_path
    
    # 8. Old password no longer works
    delete session_path
    post session_path, params: {
      email_address: @user.email_address,
      password: "oldpassword123"
    }
    assert_redirected_to new_session_path
  end
  
  test "password reset token expires after 15 minutes" do
    # Request password reset
    post passwords_path, params: { email_address: @user.email_address }
    
    # Get the token
    token = @user.password_reset_token
    
    # Travel 16 minutes into the future
    travel 16.minutes do
      # Try to use the expired token
      get edit_password_path(token)
      assert_redirected_to new_password_path
      assert_equal "Password reset link is invalid or has expired.", flash[:alert]
      
      # Try to update password with expired token
      put password_path(token), params: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
      assert_redirected_to new_password_path
      assert_equal "Password reset link is invalid or has expired.", flash[:alert]
    end
  end
  
  test "password reset doesn't work for non-existent email" do
    # Request password reset for non-existent email
    assert_no_emails do
      post passwords_path, params: { email_address: "nonexistent@example.com" }
    end
    
    # Should still show success message (to prevent email enumeration)
    assert_redirected_to new_session_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
  end
  
  test "user can request multiple password resets" do
    # First reset request
    assert_emails 1 do
      post passwords_path, params: { email_address: @user.email_address }
    end
    
    # Second reset request
    assert_emails 1 do
      post passwords_path, params: { email_address: @user.email_address }
    end
    
    # Both tokens should work (within time limit)
    token1 = @user.password_reset_token
    # Sleep briefly to ensure different timestamp in token
    sleep 0.01
    token2 = @user.password_reset_token
    
    # Different tokens should be generated (Rails signed_id includes timestamp)
    # But if they're the same, that's also acceptable for immediate requests
    
    # Both should be valid
    get edit_password_path(token1)
    assert_response :success
    
    get edit_password_path(token2)
    assert_response :success
  end
end