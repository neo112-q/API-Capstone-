class Api::V1::UsersController < ApplicationController
  before_action(:authorize_request, except: [:sign_up, :sign_in])
  before_action(:set_s3_client, only: [:update_profile])

  def sign_up()
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
      # ✅ ตรวจสอบสถานะก่อน login
      if user.banned?
        return render(json: { error: "บัญชีของคุณถูกระงับการใช้งาน กรุณาติดต่อผู้ดูแลระบบ" }, status: :forbidden)
      end

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

  def profile
    render json: {
      id: @current_user.id,
      email: @current_user.email,
      username: @current_user.username,
      pen_name: @current_user.pen_name,
      bio: @current_user.bio,
      avatar_path: @current_user.avatar_path,
      coin_balance: @current_user.coin_balance,
      role: @current_user.role,        # ✅ เพิ่ม role
      status: @current_user.status     # ✅ เพิ่ม status
    }, status: :ok
  end

  def update_profile
    if params[:avatar].present?
      avatar_url = upload_avatar_to_s3(@current_user, params[:avatar])
      @current_user.avatar_path = avatar_url
    end

    @current_user.username = params[:username] if params[:username].present?
    @current_user.pen_name = params[:pen_name] if params[:pen_name].present?
    @current_user.bio = params[:bio] if params[:bio].present?

    if @current_user.save
      render json: { message: "อัปเดตโปรไฟล์เรียบร้อย!", user: @current_user.as_json(except: [:password_digest]) }, status: :ok
    else
      render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_password
    unless @current_user.authenticate(params[:current_password])
      return render json: { error: "รหัสผ่านปัจจุบันไม่ถูกต้อง" }, status: :unauthorized
    end

    if params[:new_password] != params[:password_confirmation]
      return render json: { error: "รหัสผ่านใหม่และการยืนยันไม่ตรงกัน" }, status: :unprocessable_entity
    end

    if @current_user.update(password: params[:new_password])
      render json: { message: "เปลี่ยนรหัสผ่านสำเร็จ!" }, status: :ok
    else
      render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @current_user.authenticate(params[:password])
      @current_user.destroy()
      render(json: { message: "User deleted successfully" }, status: :ok)
    else
      render(json: { message: "Invalid password, cannot delete" }, status: :unauthorized)
    end
  end
  
  def liked_chapters
    likes = ChapterLike.where(user_id: @current_user.id).order(created_at: :desc)
    
    result = likes.map do |like|
      novel = Novel.find(like.novel_id)
      chapter = novel.chapters.find_by(chapter_no: like.chapter_no)
      
      {
        id: like.id,
        novelId: novel.id,
        novelTitle: novel.title,
        novelPenName: novel.pen_name,
        novelCoverPath: novel.cover_path,
        chapterNo: like.chapter_no,
        chapterTitle: chapter&.title || "ไม่มีชื่อตอน",
        likedAt: like.created_at,
        genres: novel.genres.as_json(only: [:id, :name])
      }
    end
    
    render(json: { liked_chapters: result }, status: :ok)
  end

  def unlocked_chapters
    user_id = params[:user_id]
    novel_id = params[:novel_id]
    
    unless @current_user && @current_user.id == user_id.to_i
      return render(json: { error: "Unauthorized" }, status: :unauthorized)
    end
    
    unlocked = UnlockedChapter.where(
      user_id: user_id,
      novel_id: novel_id
    ).pluck(:chapter_no)
    
    render(json: unlocked, status: :ok)
  end
  

  private

  def sign_up_params
    params.require(:user).permit(:email, :username, :password, :password_confirmation)
  end

  def set_s3_client
    @s3_client = Aws::S3::Client.new(
      endpoint: ENV.fetch('MINIO_ENDPOINT', 'http://host.docker.internal:9000'),
      access_key_id: ENV.fetch('MINIO_ACCESS_KEY', 'admin'),
      secret_access_key: ENV.fetch('MINIO_SECRET_KEY', 'password123'),
      region: "us-east-1",
      force_path_style: true
    )
    @bucket_name = "novels-bucket"
  end

  def upload_avatar_to_s3(user, file)
    object_key = "avatars/#{user.id}.png"

    @s3_client.put_object(
      bucket: @bucket_name,
      key: object_key,
      body: file.tempfile,        # ✅ สำคัญ
      content_type: file.content_type
    )

    "#{ENV.fetch('MINIO_PUBLIC_ENDPOINT', 'http://naphon.ddns.net:9000')}/#{@bucket_name}/#{object_key}?t=#{Time.now.to_i}"
  end

  def user_as_json(user)
    {
      id: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
      status: user.status,
      created_at: user.created_at
    }
  end
end