class UserMailer < ApplicationMailer
  default from: ENV.fetch('GMAIL_USERNAME', 'noreply@mynovel.com')

  def forgot_password(user)
    @user = user
    @otp = user.reset_password_token
    mail(to: @user.email, subject: 'รหัส OTP สำหรับรีเซ็ตรหัสผ่าน My Novel')
  end
end
