require "test_helper"

class ProfileManagementFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "profile@example.com",
      password: "password123",
      role: :marketer
    )
  end
  
  test "complete profile management flow" do
    # 1. Sign in
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
    
    # 2. Navigate to profile
    get profile_path
    assert_response :success
    assert_select "h1", "My Profile"
    
    # Check initial state - using email prefix as display name
    assert_match "profile", response.body
    assert_match "Not set", response.body # Various fields not set
    
    # 3. Click Edit Profile
    assert_select "a[href=?]", edit_profile_path, "Edit Profile"
    
    get edit_profile_path
    assert_response :success
    assert_select "h1", "Edit Profile"
    
    # 4. Fill out profile form
    patch profile_path, params: {
      user: {
        full_name: "John Marketer",
        bio: "I'm a digital marketing professional with 10 years of experience.",
        phone_number: "+1 555-123-4567",
        company: "Marketing Pro Inc",
        job_title: "Senior Marketing Manager",
        timezone: "Pacific Time (US & Canada)",
        notification_email: true,
        notification_marketing: false,
        notification_product: true
      }
    }
    
    assert_redirected_to profile_path
    follow_redirect!
    
    # 5. Verify profile was updated
    assert_select "#notice", "Profile updated successfully."
    assert_match "John Marketer", response.body
    assert_match "digital marketing professional", response.body
    assert_match "+1 555-123-4567", response.body
    assert_match "Marketing Pro Inc", response.body
    assert_match "Senior Marketing Manager", response.body
    assert_match /Pacific Time \(US (&amp;|&) Canada\)/, response.body
    
    # 6. Check navigation shows display name
    assert_match "Hello, John Marketer", response.body
    
    # 7. Verify data persistence
    @user.reload
    assert_equal "John Marketer", @user.full_name
    assert_equal false, @user.notification_marketing
  end
  
  test "profile validation errors are shown" do
    sign_in_as(@user)
    
    get edit_profile_path
    assert_response :success
    
    # Submit invalid data
    patch profile_path, params: {
      user: {
        full_name: "a" * 101, # Too long
        phone_number: "not a phone number!",
        timezone: "Mars/Olympus_Mons" # Invalid timezone
      }
    }
    
    assert_response :unprocessable_entity
    assert_select "#error_explanation"
    assert_match "is too long", response.body
    assert_match "is invalid", response.body
    assert_match "is not included in the list", response.body
  end
  
  test "profile requires authentication" do
    # Try to access profile without signing in
    get profile_path
    assert_redirected_to new_session_path
    
    get edit_profile_path
    assert_redirected_to new_session_path
    
    patch profile_path, params: { user: { full_name: "Hacker" } }
    assert_redirected_to new_session_path
  end
  
  test "avatar upload workflow" do
    sign_in_as(@user)
    
    get edit_profile_path
    assert_response :success
    
    # Check for file input
    assert_select "input[type=file][name='user[avatar]']"
    assert_match "JPG, PNG, GIF or WebP. Max 5MB", response.body
  end
  
  test "notification preferences can be toggled" do
    sign_in_as(@user)
    
    # Check initial state (all true by default)
    assert @user.notification_email
    assert @user.notification_marketing
    assert @user.notification_product
    
    # Update preferences
    patch profile_path, params: {
      user: {
        notification_email: "0",
        notification_marketing: "0", 
        notification_product: "1"
      }
    }
    
    assert_redirected_to profile_path
    
    @user.reload
    assert_equal false, @user.notification_email
    assert_equal false, @user.notification_marketing
    assert_equal true, @user.notification_product
  end
  
  private
  
  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end