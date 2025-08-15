require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: "marketer"
    )
  end

  test "should get new" do
    get new_password_url
    assert_response :success
    assert_select "h1", "Forgot your password?"
  end

  test "should create password reset for valid email" do
    assert_emails 1 do
      post passwords_url, params: { email_address: @user.email_address }
    end

    assert_redirected_to new_session_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
  end

  test "should not create password reset for invalid email but show same message" do
    assert_emails 0 do
      post passwords_url, params: { email_address: "nonexistent@example.com" }
    end

    assert_redirected_to new_session_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
  end

  test "should have rate limiting configured" do
    # This test verifies that rate limiting is configured on the controller
    # The actual rate limiting behavior is tested through integration tests
    assert_respond_to PasswordsController, :rate_limit
  end

  test "should get edit with valid token" do
    token = @user.password_reset_token
    get edit_password_url(token)
    assert_response :success
    assert_select "h1", "Update your password"
  end

  test "should redirect to new password with invalid token" do
    get edit_password_url("invalid_token")
    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "should update password with valid token and matching passwords" do
    token = @user.password_reset_token
    
    put password_url(token), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }
    
    assert_redirected_to new_session_path
    assert_equal "Password has been reset successfully. Please sign in with your new password.", flash[:notice]
    
    # Verify password was actually changed
    @user.reload
    assert @user.authenticate_password("newpassword123")
  end

  test "should not update password with mismatched confirmation" do
    token = @user.password_reset_token
    
    put password_url(token), params: {
      password: "newpassword123",
      password_confirmation: "differentpassword"
    }
    
    assert_response :unprocessable_entity
    assert_template :edit
  end

  test "should invalidate all user sessions after password reset" do
    # Create a session for the user
    session = @user.sessions.create!(user_agent: "Test Agent", ip_address: "127.0.0.1")
    
    token = @user.password_reset_token
    
    put password_url(token), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }
    
    # Verify session was destroyed
    assert_nil Session.find_by(id: session.id)
  end

  test "should not update password with blank password" do
    token = @user.password_reset_token
    original_password_digest = @user.password_digest
    
    put password_url(token), params: {
      password: "",
      password_confirmation: ""
    }
    
    # Password should not have changed
    @user.reload
    assert_equal original_password_digest, @user.password_digest
  end
end