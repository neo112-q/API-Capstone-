class Api::V1::PasswordsController < ::ApplicationController
  before_action :authorize_request, except: [:forgot, :reset]

  def forgot
    if params[:email].blank?
      return render json: { error: 'กรุณาระบุอีเมล' }, status: :bad_request
    end

    user = User.find_by(email: params[:email].downcase)
    if user.present?
      user.generate_password_reset_token
      UserMailer.forgot_password(user).deliver_now
    end

    render json: { message: 'หากอีเมลนี้อยู่ในระบบ รหัส OTP จะถูกส่งไปยังอีเมลของคุณ' }, status: :ok
  end

  def reset
    user = User.find_by(email: params[:email]&.downcase, reset_password_token: params[:token])

    if user.present? && user.password_reset_valid?
      if user.update(password: params[:password], reset_password_token: nil, reset_password_sent_at: nil)
        render json: { message: 'เปลี่ยนรหัสผ่านสำเร็จ!' }, status: :ok
      else
        render json: { error: user.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'รหัส OTP ไม่ถูกต้องหรือหมดอายุแล้ว' }, status: :bad_request
    end
  end
end