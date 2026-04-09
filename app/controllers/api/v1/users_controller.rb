class Api::V1::UsersController < ApplicationController
  before_action(:authorize_request, except: [:sign_up, :sign_in, :destroy])
  before_action(:set_s3_client, only: [:update_profile])

  def sign_up
    user = User.new(sign_up_params())

    if user.save()
      token = JsonWebToken.encode(payload: { user_id: user.id })
      render(json: {
        message: "Sign up successful",
        token: token,
        user: user_as_json(user)
      }, status: :created)
    else
      render(json: {
        message: "Sign up failed", 
        errors: user.errors.full_messages 
      }, status: :unprocessable_entity)
    end
  end

  def sign_in
    user = User.find_by(email: params[:identifier]&.downcase()) || 
           User.find_by(username: params[:identifier]&.downcase())

    if user&.authenticate(params[:password])
      token = JsonWebToken.encode(payload: { user_id: user.id })
      render(json: {
        message: "Sign in successful",
        token: token,
        user: user_as_json(user)
      }, status: :ok)
    else
      render(json: { message: "Invalid email/username or password" }, status: :unauthorized)
    end
  end

  # Rดึงข้อมูลผู้ใช้ไปโชว์ในหน้าตั้งค่า
  def profile
    # ไม่ส่ง password กลับไปแน่ ๆ อะ 555
    render json: {
      id: @current_user.id,
      email: @current_user.email,
      username: @current_user.username,
      pen_name: @current_user.pen_name,
      bio: @current_user.bio,
      avatar_path: @current_user.avatar_path
    }, status: :ok
  end

  # U (รูป, ชื่อ, นามปากกา, bio)
  def update_profile
    # ถ้ามีการอัปโหลดรูปภาพใหม่ (โยนขึ้น S3)
    if params[:avatar_content].present?
      avatar_url = upload_avatar_to_s3(@current_user, params[:avatar_content])
      @current_user.avatar_path = avatar_url
    end

    # อัปเดตฟิลด์อื่น ๆ
    @current_user.username = params[:username] if params[:username].present?
    @current_user.pen_name = params[:pen_name] if params[:pen_name].present?
    @current_user.bio = params[:bio] if params[:bio].present?
    #  เปลี่ยนอีเมล
    # @current_user.email = params[:email] if params[:email].present?

    if @current_user.save
      render json: { message: "อัปเดตโปรไฟล์เรียบร้อย!", user: @current_user.as_json(except: [:password_digest]) }, status: :ok
    else
      render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # [UPDATE] เปลี่ยนรหัสผ่าน (Security UI)
  def update_password
    # 1. เช็คความปลอดภัย: รหัสผ่านเก่าถูกไหม?
    unless @current_user.authenticate(params[:current_password])
      return render json: { error: "รหัสผ่านปัจจุบันไม่ถูกต้อง" }, status: :unauthorized
    end

    # 2. เช็คว่ารหัสใหม่กับรหัสยืนยันตรงกันไหม?
    if params[:new_password] != params[:password_confirmation]
      return render json: { error: "รหัสผ่านใหม่และการยืนยันไม่ตรงกัน" }, status: :unprocessable_entity
    end

    # 3. เซฟรหัสใหม่
    if @current_user.update(password: params[:new_password])
      render json: { message: "เปลี่ยนรหัสผ่านสำเร็จ! กรุณาล็อกอินใหม่" }, status: :ok
    else
      render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    user = User.find_by(email: params[:identifier]&.downcase()) || 
           User.find_by(username: params[:identifier]&.downcase())

    if user
      if user.authenticate(params[:password])
        user.destroy()
        render(json: { message: "User deleted successfully" }, status: :ok)
      else
        render(json: { message: "Invalid password, cannot delete" }, status: :unauthorized)
      end
    else
      render(json: { message: "User not found" }, status: :not_found)
    end
  end

  private

  def sign_up_params()
    params.require(:user).permit(:email, :username, :password, :password_confirmation)
  end

  def set_s3_client
    @s3_client = Aws::S3::Client.new(
      endpoint: "http://localhost:9000",
      access_key_id: "admin_o",
      secret_access_key: "password_o123",
      region: "us-east-1",
      force_path_style: true
    )
    @bucket_name = "novels-bucket"
  end

  def upload_avatar_to_s3(user, file_content)
    begin
      @s3_client.create_bucket(bucket: @bucket_name)
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou, Aws::S3::Errors::BucketAlreadyExists
    end

    object_key = "avatars/#{user.id}.png"

    @s3_client.put_object(
      bucket: @bucket_name,
      key: object_key,
      body: file_content # เผื่อ Base64
    )

    return "/#{@bucket_name}/#{object_key}"
  end


  def user_as_json(user)
    {
      id: user.id,
      email: user.email,
      username: user.username,
      created_at: user.created_at
    }
  end
end
