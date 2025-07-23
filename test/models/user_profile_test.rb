require "test_helper"

class UserProfileTest < ActiveSupport::TestCase
  setup do
    @user = User.new(
      email_address: "test@example.com",
      password: "password123"
    )
  end
  
  # Profile field validations
  test "full name should not exceed 100 characters" do
    @user.full_name = "a" * 101
    assert_not @user.valid?
    assert_includes @user.errors[:full_name], "is too long (maximum is 100 characters)"
  end
  
  test "bio should not exceed 500 characters" do
    @user.bio = "a" * 501
    assert_not @user.valid?
    assert_includes @user.errors[:bio], "is too long (maximum is 500 characters)"
  end
  
  test "phone number should accept valid formats" do
    valid_phones = ["+1 555-1234", "555-1234", "(555) 123-4567", "+44 20 7946 0958"]
    valid_phones.each do |phone|
      @user.phone_number = phone
      assert @user.valid?, "#{phone} should be valid"
    end
  end
  
  test "phone number should reject invalid formats" do
    @user.phone_number = "invalid phone!"
    assert_not @user.valid?
    assert_includes @user.errors[:phone_number], "is invalid"
  end
  
  test "company should not exceed 100 characters" do
    @user.company = "a" * 101
    assert_not @user.valid?
    assert_includes @user.errors[:company], "is too long (maximum is 100 characters)"
  end
  
  test "job title should not exceed 100 characters" do
    @user.job_title = "a" * 101
    assert_not @user.valid?
    assert_includes @user.errors[:job_title], "is too long (maximum is 100 characters)"
  end
  
  test "timezone should be valid" do
    @user.timezone = "Eastern Time (US & Canada)"
    assert @user.valid?
    
    @user.timezone = "Invalid/Timezone"
    assert_not @user.valid?
    assert_includes @user.errors[:timezone], "is not included in the list"
  end
  
  test "timezone defaults to UTC" do
    user = User.create!(email_address: "utc@example.com", password: "password123")
    assert_equal "UTC", user.timezone
  end
  
  # Notification preferences
  test "notification preferences default to true" do
    user = User.create!(email_address: "notify@example.com", password: "password123")
    assert_equal true, user.notification_email
    assert_equal true, user.notification_marketing
    assert_equal true, user.notification_product
  end
  
  # Display name
  test "display_name returns full name when present" do
    @user.full_name = "John Doe"
    assert_equal "John Doe", @user.display_name
  end
  
  test "display_name returns email prefix when full name is blank" do
    @user.full_name = ""
    assert_equal "test", @user.display_name
    
    @user.full_name = nil
    assert_equal "test", @user.display_name
  end
  
  # Avatar tests
  test "avatar can be attached" do
    @user.save!
    assert @user.avatar.respond_to?(:attach)
  end
  
  test "avatar accepts valid image types" do
    @user.save!
    
    # Mock avatar blob
    @user.avatar.attach(
      io: StringIO.new("fake image data"),
      filename: "avatar.jpg",
      content_type: "image/jpeg"
    )
    
    assert @user.valid?
  end
  
  test "avatar rejects files over 5MB" do
    @user.save!
    
    # Mock large avatar blob
    @user.avatar.attach(
      io: StringIO.new("x" * 6.megabytes),
      filename: "large.jpg",
      content_type: "image/jpeg"
    )
    
    assert_not @user.valid?
    assert_includes @user.errors[:avatar], "is too big (should be at most 5MB)"
  end
  
  test "avatar rejects non-image files" do
    @user.save!
    
    # Mock non-image blob
    @user.avatar.attach(
      io: StringIO.new("not an image"),
      filename: "document.pdf",
      content_type: "application/pdf"
    )
    
    assert_not @user.valid?
    assert_includes @user.errors[:avatar], "must be a JPEG, PNG, GIF, or WebP"
  end
  
  test "avatar_variant returns nil when no avatar attached" do
    @user.save!
    assert_nil @user.avatar_variant(:thumb)
  end
end