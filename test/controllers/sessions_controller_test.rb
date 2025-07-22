require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "test@example.com", password: "password123")
  end
  
  test "should get new" do
    get new_session_url
    assert_response :success
  end
  
  test "should create session with valid credentials" do
    assert_difference("Session.count") do
      post session_url, params: { email_address: @user.email_address, password: "password123" }
    end
    
    assert_redirected_to root_url
    assert_not_nil cookies[:session_id]
  end
  
  test "should not create session with invalid credentials" do
    assert_no_difference("Session.count") do
      post session_url, params: { email_address: @user.email_address, password: "wrongpassword" }
    end
    
    assert_redirected_to new_session_url
    assert_equal "Try another email address or password.", flash[:alert]
  end
  
  test "should destroy session" do
    # First sign in
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    session_id = cookies[:session_id]
    
    assert_difference("Session.count", -1) do
      delete session_url
    end
    
    assert_redirected_to new_session_url
    assert cookies[:session_id].blank?
  end
end