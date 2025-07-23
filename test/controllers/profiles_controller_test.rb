require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: :marketer,
      full_name: "Test User",
      bio: "A test bio",
      phone_number: "+1 555-1234",
      company: "Test Corp",
      job_title: "Marketing Manager",
      timezone: "Eastern Time (US & Canada)"
    )
    sign_in_as(@user)
  end

  test "should get show" do
    get profile_path
    assert_response :success
    assert_select "h1", "My Profile"
    assert_match @user.full_name, response.body
    assert_match @user.email_address, response.body
  end

  test "should get edit" do
    get edit_profile_path
    assert_response :success
    assert_select "h1", "Edit Profile"
    assert_select "form"
  end

  test "should update profile with valid data" do
    patch profile_path, params: { 
      user: { 
        full_name: "Updated Name",
        bio: "Updated bio",
        phone_number: "+1 555-9999",
        company: "New Company",
        job_title: "Senior Manager",
        timezone: "Pacific Time (US & Canada)",
        notification_email: false,
        notification_marketing: false,
        notification_product: true
      } 
    }
    
    assert_redirected_to profile_path
    follow_redirect!
    assert_select "#notice", "Profile updated successfully."
    
    @user.reload
    assert_equal "Updated Name", @user.full_name
    assert_equal "Updated bio", @user.bio
    assert_equal "+1 555-9999", @user.phone_number
    assert_equal "New Company", @user.company
    assert_equal "Senior Manager", @user.job_title
    assert_equal "Pacific Time (US & Canada)", @user.timezone
    assert_equal false, @user.notification_email
    assert_equal false, @user.notification_marketing
    assert_equal true, @user.notification_product
  end

  test "should not update profile with invalid data" do
    patch profile_path, params: { 
      user: { 
        phone_number: "invalid phone",
        timezone: "Invalid Timezone"
      } 
    }
    
    assert_response :unprocessable_entity
    assert_select "#error_explanation"
  end

  test "requires authentication to view profile" do
    delete session_path # Sign out
    
    get profile_path
    assert_redirected_to new_session_path
    
    get edit_profile_path
    assert_redirected_to new_session_path
    
    patch profile_path, params: { user: { full_name: "Hacker" } }
    assert_redirected_to new_session_path
  end

  test "display_name shows full name when present" do
    get profile_path
    assert_match @user.full_name, response.body
  end

  test "display_name shows email prefix when full name is blank" do
    @user.update!(full_name: "")
    get profile_path
    assert_match "test", response.body # from test@example.com
  end

  private

  def sign_in_as(user)
    post session_path, params: { 
      email_address: user.email_address, 
      password: "password123" 
    }
  end
end
