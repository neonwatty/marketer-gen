require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      full_name: "Test User",
      role: "marketer"
    )
  end
  
  test "account_temporarily_locked sends to user" do
    email = UserMailer.account_temporarily_locked(@user)
    
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal [@user.email_address], email.to
    assert_equal "Your account has been temporarily locked", email.subject
    assert_equal ["from@example.com"], email.from
  end
  
  test "account_temporarily_locked email body contains helpful information" do
    travel_to Time.current do
      email = UserMailer.account_temporarily_locked(@user)
      unlock_time = 1.hour.from_now
      
      # Check HTML version
      assert_match "Test User", email.html_part.body.to_s
      assert_match "temporarily locked", email.html_part.body.to_s
      assert_match "suspicious activity", email.html_part.body.to_s
      assert_match unlock_time.strftime("%I:%M %p on %B %d, %Y"), email.html_part.body.to_s
      assert_match "Security Tips", email.html_part.body.to_s
      assert_match "strong, unique password", email.html_part.body.to_s
      
      # Check text version
      assert_match "Test User", email.text_part.body.to_s
      assert_match "temporarily locked", email.text_part.body.to_s
      assert_match "suspicious activity", email.text_part.body.to_s
      assert_match unlock_time.strftime("%I:%M %p on %B %d, %Y"), email.text_part.body.to_s
    end
  end
  
  test "uses email address when full name not present" do
    @user.update!(full_name: nil)
    email = UserMailer.account_temporarily_locked(@user)
    
    assert_match @user.email_address, email.html_part.body.to_s
    assert_match @user.email_address, email.text_part.body.to_s
  end
end