require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: :marketer
    )
  end
  
  test "reset email" do
    # Create the email
    email = PasswordsMailer.reset(@user)
    
    # Send the email, then test that it got queued
    assert_emails 1 do
      email.deliver_now
    end
    
    # Test the email contents
    assert_equal ["test@example.com"], email.to
    assert_equal "Reset your password", email.subject
    assert_equal ["from@example.com"], email.from
    
    # Test email body contains reset link
    email_body = email.text_part ? email.text_part.body.to_s : email.body.to_s
    assert_match "You can reset your password within the next 15 minutes", email_body
    assert_match "password reset page", email_body
    assert_match %r{passwords/[^/]+/edit}, email_body
  end
  
  test "reset email contains valid reset link" do
    email = PasswordsMailer.reset(@user)
    
    # Extract the reset URL from the email body
    reset_token = @user.password_reset_token
    
    # Check both HTML and text versions contain a password reset link
    assert_match %r{passwords/[^/]+/edit}, email.html_part.body.to_s
    assert_match %r{passwords/[^/]+/edit}, email.text_part.body.to_s
  end
  
  test "reset email uses user's email address" do
    custom_user = User.create!(
      email_address: "custom@example.com",
      password: "password123",
      role: :admin
    )
    
    email = PasswordsMailer.reset(custom_user)
    
    assert_equal ["custom@example.com"], email.to
  end
end