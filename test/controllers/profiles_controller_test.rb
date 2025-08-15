require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: "marketer",
      first_name: "John",
      last_name: "Doe"
    )
    
    # Create a session for the user
    @session = @user.sessions.create!(user_agent: "Test Agent", ip_address: "127.0.0.1")
  end

  def sign_in_as(user)
    session = user.sessions.first
    # Simulate the authentication process by setting the session cookie
    post session_url, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end

  test "should show profile when authenticated" do
    sign_in_as(@user)
    get profile_url
    assert_response :success
    assert_select "h1", "John Doe"
    assert_select "p", @user.email_address
  end

  test "should redirect to sign in when not authenticated" do
    get profile_url
    assert_redirected_to new_session_path
  end

  test "should get edit profile when authenticated" do
    sign_in_as(@user)
    get edit_profile_url
    assert_response :success
    assert_select "h1", "Edit Profile"
    assert_select "input[name='user[first_name]'][value='John']"
    assert_select "input[name='user[last_name]'][value='Doe']"
  end

  test "should update profile with valid data" do
    sign_in_as(@user)
    
    patch profile_url, params: {
      user: {
        first_name: "Jane",
        last_name: "Smith",
        phone: "+1-555-123-4567",
        company: "Test Corp",
        bio: "Software developer with 5 years experience",
        notification_preferences: {
          email_notifications: "true",
          journey_updates: "false",
          marketing_emails: "true",
          weekly_digest: "true"
        }
      }
    }
    
    assert_redirected_to profile_path
    assert_equal "Profile updated successfully.", flash[:notice]
    
    @user.reload
    assert_equal "Jane", @user.first_name
    assert_equal "Smith", @user.last_name
    assert_equal "+1-555-123-4567", @user.phone
    assert_equal "Test Corp", @user.company
    assert_equal "Software developer with 5 years experience", @user.bio
    assert_equal true, @user.notification_preferences['email_notifications']
    assert_equal false, @user.notification_preferences['journey_updates']
  end

  test "should not update profile with invalid data" do
    sign_in_as(@user)
    
    patch profile_url, params: {
      user: {
        first_name: "a" * 60,  # Too long
        phone: "invalid phone",
        bio: "a" * 600  # Too long
      }
    }
    
    assert_response :unprocessable_entity
    assert_template :edit
    
    @user.reload
    assert_equal "John", @user.first_name  # Should not change
  end

  test "should display user stats on profile" do
    # Create some journeys for the user
    journey1 = @user.journeys.create!(name: "Journey 1", campaign_type: "awareness", status: "active")
    journey2 = @user.journeys.create!(name: "Journey 2", campaign_type: "awareness", status: "draft")
    
    sign_in_as(@user)
    get profile_url
    
    assert_response :success
    assert_select ".text-3xl.font-bold.text-blue-600", "2"  # Total journeys
    assert_select ".text-3xl.font-bold.text-green-600", "1"  # Active journeys
  end

  test "should show initials when no avatar" do
    sign_in_as(@user)
    get profile_url
    
    assert_response :success
    assert_select "div", text: "JD"  # John Doe initials
  end

  test "should handle notification preferences correctly" do
    sign_in_as(@user)
    
    # Test with some preferences disabled
    patch profile_url, params: {
      user: {
        notification_preferences: {
          email_notifications: "false",
          journey_updates: "false",
          marketing_emails: "false",
          weekly_digest: "false"
        }
      }
    }
    
    assert_redirected_to profile_path
    
    @user.reload
    assert_equal false, @user.notification_preferences['email_notifications']
    assert_equal false, @user.notification_preferences['journey_updates']
    assert_equal false, @user.notification_preferences['marketing_emails']
    assert_equal false, @user.notification_preferences['weekly_digest']
  end
end
