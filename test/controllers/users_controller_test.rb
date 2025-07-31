require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @marketer = users(:regular)
    @admin = users(:admin)
    @other_user = users(:two)
  end
  
  # Index action tests
  test "admin can access users index" do
    sign_in_as(@admin, "password")
    
    get users_path
    assert_response :success
  end
  
  test "non-admin cannot access users index" do
    sign_in_as(@marketer, "password")
    
    get users_path
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end
  
  test "unauthenticated user is redirected from users index" do
    get users_path
    assert_redirected_to new_session_path
  end
  
  # Show action tests
  test "user can view their own profile" do
    sign_in_as(@marketer, "password")
    
    get user_path(@marketer)
    assert_response :success
  end
  
  test "user cannot view other user profiles" do
    sign_in_as(@marketer, "password")
    
    get user_path(@other_user)
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end
  
  test "admin can view any user profile" do
    sign_in_as(@admin, "password")
    
    get user_path(@marketer)
    assert_response :success
    
    get user_path(@other_user)
    assert_response :success
  end
  
  test "unauthenticated user is redirected from user show" do
    get user_path(@marketer)
    assert_redirected_to new_session_path
  end
  
end
