require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get sign_up_url
    assert_response :success
  end

  test "should create user" do
    assert_difference("User.count") do
      post sign_up_url, params: { user: { email_address: "test@example.com", password: "password123", password_confirmation: "password123" } }
    end
    
    assert_redirected_to root_url
    assert_not_nil cookies[:session_id]
  end
  
  test "should not create user with invalid params" do
    assert_no_difference("User.count") do
      post sign_up_url, params: { user: { email_address: "", password: "short", password_confirmation: "different" } }
    end
    
    assert_response :unprocessable_entity
  end
end
