require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers
  
  def setup
    Rails.application.routes.default_url_options[:host] = 'test.host'
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: "marketer"
    )
  end

  test "reset email contains correct information" do
    email = PasswordsMailer.reset(@user)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["noreply@marketer-gen.com"], email.from
    assert_equal [@user.email_address], email.to
    assert_equal "Reset your password", email.subject
    
    # Check HTML body
    assert_match "Reset Your Password", email.html_part.body.to_s
    assert_match "Marketer Gen account", email.html_part.body.to_s
    assert_match "/passwords/", email.html_part.body.to_s
    assert_match "expire in 15 minutes", email.html_part.body.to_s
    
    # Check text body
    assert_match "Reset Your Password - Marketer Gen", email.text_part.body.to_s
    assert_match "/passwords/", email.text_part.body.to_s
    assert_match "expire in 15 minutes", email.text_part.body.to_s
  end

  test "reset email includes password reset token URL" do
    email = PasswordsMailer.reset(@user)
    
    # Check that the email contains password reset links
    assert_match "/passwords/", email.html_part.body.to_s
    assert_match "/passwords/", email.text_part.body.to_s
    assert_match "/edit", email.html_part.body.to_s
    assert_match "/edit", email.text_part.body.to_s
  end

  test "reset email has proper styling in HTML version" do
    email = PasswordsMailer.reset(@user)
    html_body = email.html_part.body.to_s
    
    assert_match 'style=', html_body
    assert_match 'background-color: #2563eb', html_body
    assert_match 'font-family: Arial', html_body
  end
end