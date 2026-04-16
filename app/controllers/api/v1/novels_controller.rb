class Api::V1::NovelsController < ::ApplicationController
  # เรียก Token เฉพาะตอน C, U, D
  before_action(:authorize_request, only: [:create, :update, :destroy, :my_novels])
  # เตรียมเชื่อม S3 รอไว้เลย จะได้เรียกใช้จัดการรูปปก
  before_action(:set_s3_client, only: [:create, :update, :destroy])

  # หมวดหมู่ที่อนุญาตให้เลือกได้
  def genres_list()
    all_genres = Genre.pluck(:name)
    render(json: { genres: all_genres }, status: :ok)
  end

  # ดูได้ทุกคนนะ
  def index()
    render(json: Novel.all().order(updated_at: :desc), include: :genres)
  end

  # สร้างนิยาย ดึง user_id จาก Token อัตโนมัติ
  def create()
    genre_objects = Genre.where(name: sanitize_genres(params[:novel][:genres]))
    
    # 🔥 ใช้ pen_name ที่ส่งมาจาก frontend แทนการดึงจาก current_user
    pen_name = params[:novel][:pen_name].presence || @current_user.username
    
    novel = @current_user.novels.build(
      title: params[:novel][:title],
      description: params[:novel][:description],
      pen_name: pen_name,  # ใช้ค่าที่ส่งมา
      genres: genre_objects
    )
    
    if novel.save()
      if params[:cover_content].present?
        cover_url = upload_cover_to_s3(novel, params[:cover_content])
        novel.update_columns(cover_path: cover_url)
      end

      render(json: novel, status: :created)
    else
      render(json: { errors: novel.errors.full_messages }, status: :unprocessable_entity)
    end
  end

  # แก้ไขข้อมูล แก้ได้เฉพาะนิยายของตัวเองเท่านั้นนะ
  def update()
    novel = @current_user.novels.find(params[:id])
    
    # อัปเดตข้อมูลทั่วไป
    novel.title = params[:novel][:title] if params[:novel][:title].present?
    novel.description = params[:novel][:description] if params[:novel][:description].present?
    
    
    if params[:novel][:genres]
      novel.genres = Genre.where(name: params[:novel][:genres])
    end

    # ถ้ามีการส่งรูปปกใหม่มา โยนทับไฟล์เดิมได้เลย
    if params[:cover_content].present?
      novel.cover_path = upload_cover_to_s3(novel, params[:cover_content])
    end

    if params[:novel][:genres]
      update_genres(novel, params[:novel][:genres])
    end

    if novel.save()
      render(json: novel, include: :genres)
    else
      render(json: { errors: novel.errors.full_messages }, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "You don't have permission to update this novel" }, status: :forbidden)
  end

  def update_genres(novel, genre_names)
    genres = Genre.where(name: genre_names)
    novel.genres = genres
  end

  def show()
    novel = Novel.find(params[:id])

    render(json: {
      id: novel.id,
      title: novel.title,
      pen_name: novel.pen_name,
      description: novel.description,
      genres: novel.genres, # ส่งหมวดหมู่กลับไปโชว์ด้วย
      cover_path: novel.cover_path # ส่งที่อยู่รูปปกกลับไปโชว์ด้วย
    }, status: :ok)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "ไม่พบนิยาย" }, status: :not_found)
  end

  def my_novels()
    begin
      novels = @current_user.novels.order(updated_at: :desc)
      render(json: novels.as_json(include: { genres: { only: [:id, :name] } }), status: :ok)
    rescue => e
      puts "Error in my_novels: #{e.message}"
      render(json: { error: e.message }, status: :internal_server_error)
    end
  end

  # ลบได้เฉพาะนิยายของตัวเองเท่านั้น
  def destroy()
    novel = @current_user.novels.find(params[:id])
    
    # ลบรูปปกออกจากโกดัง S3 ก่อน (ถ้ามีรูป)
    delete_cover_from_s3(novel) if novel.cover_path.present?
    
    novel.destroy()
    render(json: { message: "Your novel has been deleted" }, status: :ok)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "You don't have permission to delete this novel" }, status: :forbidden)
  end

  private

  def novel_params()
    # รับแค่ metadata ไม่ลึก ๆ นะ เพื่อความปลอดภัย
    params.require(:novel).permit(:title, :description, :cover_path)
  end

  # ฟังก์ชันกรอง
  def sanitize_genres(genres_array)
    return [] unless genres_array.is_a?(Array)
    
    # ดึงรายชื่อหมวดหมู่จาก DB สด ๆ ร้อน ๆ
    allowed_from_db = Genre.pluck(:name).map(&:downcase)
    
    # กรองเอาเฉพาะอันที่มีใน DB 
    genres_array.map(&:downcase).select { |g| allowed_from_db.include?(g) }
  end

  # ฟังก์ชันสำหรับเตรียม S3
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

  # โหลดรูปปกขึ้น S3
  require 'base64'

  def upload_cover_to_s3(novel, file_content)
    begin
      @s3_client.create_bucket(bucket: @bucket_name)
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou, Aws::S3::Errors::BucketAlreadyExists
    end

    object_key = "covers/#{novel.id}.png"

    decoded_image = Base64.decode64(file_content)

    @s3_client.put_object(
      bucket: @bucket_name,
      key: object_key,
      body: decoded_image,
      content_type: "image/png",   # 🔥 ตัวนี้แหละ
      content_disposition: "inline" # 🔥 บังคับให้แสดง ไม่โหลด
    )

    return "http://localhost:9000/#{@bucket_name}/#{object_key}"
  end

  # ลบรูปปกใน S3 ทิ้ง
  def delete_cover_from_s3(novel)
    object_key = "covers/#{novel.id}.png"
    @s3_client.delete_object(bucket: @bucket_name, key: object_key)
  end
end