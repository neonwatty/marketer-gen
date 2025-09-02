require "test_helper"

class Api::V1::ValidationsControllerTest < ActionDispatch::IntegrationTest
  
  def setup
    @user = users(:marketer_user)
  end

  # Email validation tests
  test "should allow email validation without authentication" do
    # Should not require authentication for email validation
    post api_v1_users_email_address_path, 
         params: { value: "test@example.com" },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["valid"]
  end

  test "should validate email format" do
    post api_v1_users_email_address_path,
         params: { value: "invalid-email" },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_not json_response["valid"]
    assert_includes json_response["errors"], "Please enter a valid email address"
  end

  test "should check email uniqueness" do
    # Use existing user's email
    existing_email = @user.email_address
    
    post api_v1_users_email_address_path,
         params: { value: existing_email },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_not json_response["valid"]
    assert_includes json_response["errors"], "This email address is already taken"
  end

  test "should allow same email for user editing their profile" do
    sign_in_as(@user)
    
    post api_v1_users_email_address_path,
         params: { value: @user.email_address, user_id: @user.id },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["valid"]
  end

  # Campaign plan name validation tests
  test "should require authentication for campaign plan name validation" do
    post api_v1_campaign_plans_name_path,
         params: { value: "Test Campaign" },
         as: :json
    
    assert_redirected_to new_session_path
  end

  test "should validate campaign plan name when authenticated" do
    sign_in_as(@user)
    
    post api_v1_campaign_plans_name_path,
         params: { value: "Valid Campaign Name" },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["valid"]
  end

  test "should reject empty campaign plan name" do
    sign_in_as(@user)
    
    post api_v1_campaign_plans_name_path,
         params: { value: "" },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_not json_response["valid"]
    assert_includes json_response["errors"], "Name is required"
  end

  test "should reject campaign plan name that is too short" do
    sign_in_as(@user)
    
    post api_v1_campaign_plans_name_path,
         params: { value: "ab" },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_not json_response["valid"]
    assert_includes json_response["errors"], "Name must be between 3 and 100 characters"
  end

  test "should reject duplicate campaign plan name for same user" do
    sign_in_as(@user)
    existing_plan = campaign_plans(:draft_plan)
    existing_plan.update!(user: @user)
    
    post api_v1_campaign_plans_name_path,
         params: { value: existing_plan.name },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_not json_response["valid"]
    assert_includes json_response["errors"], "You already have a campaign plan with this name"
  end

  # Journey name validation tests
  test "should require authentication for journey name validation" do
    post api_v1_journeys_name_path,
         params: { value: "Test Journey" },
         as: :json
    
    assert_redirected_to new_session_path
  end

  test "should validate journey name when authenticated" do
    sign_in_as(@user)
    
    post api_v1_journeys_name_path,
         params: { value: "Valid Journey Name" },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["valid"]
  end

  test "should reject empty journey name" do
    sign_in_as(@user)
    
    post api_v1_journeys_name_path,
         params: { value: "" },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_not json_response["valid"]
    assert_includes json_response["errors"], "Name is required"
  end

  test "should return JSON for AJAX requests" do
    # Test that validation endpoints return JSON, not HTML
    post api_v1_users_email_address_path,
         params: { value: "test@example.com" },
         xhr: true
    
    assert_response :success
    assert_equal "application/json", response.content_type.split(";").first
    
    # Should be able to parse JSON without errors
    assert_nothing_raised do
      JSON.parse(response.body)
    end
  end
end