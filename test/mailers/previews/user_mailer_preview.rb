# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def account_temporarily_locked
    user = User.first || User.new(
      email_address: "locked@example.com",
      full_name: "John Doe",
      locked_at: Time.current,
      lock_reason: "Suspicious activity detected"
    )
    
    UserMailer.account_temporarily_locked(user)
  end
end