class UserMailer < ApplicationMailer
  def account_temporarily_locked(user)
    @user = user
    @unlock_time = 1.hour.from_now
    
    mail(
      to: @user.email_address,
      subject: "Your account has been temporarily locked"
    )
  end
end