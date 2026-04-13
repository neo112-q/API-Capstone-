class Api::V1::NovelsController < ::ApplicationController
  # เรียก Token เฉพาะตอน C, U, D
  before_action(:authorize_request, only: [:create, :update, :destroy])
  # เตรียมเชื่อม S3 รอไว้เลย จะได้เรียกใช้จัดการรูปปก
  before_action(:set_s3_client, only: [:create, :update, :destroy])

  # หมวดหมู่ที่อนุญาตให้เลือกได้
  ALLOWED_GENRES = [
    "romance", "comedy", "girl love", "boy love", "fantasy", 
    "science", "fiction", "mystery", "war", "adventure", 
    "action", "thriller", "horror"
  ].freeze

  # ดูได้ทุกคนนะ
  def index()
    render(json: Novel.all().order(updated_at: :desc))
  end

  # สร้างนิยาย ดึง user_id จาก Token อัตโนมัติ
  def create()
    novel = @current_user.novels.build(
      title: params[:novel][:title],
      description: params[:novel][:description],
      pen_name: @current_user.pen_name,
      genres: sanitize_genres(params[:novel][:genres]) # กรองหมวดหมู่ก่อนบันทึก
    )
    
    if novel.save()
      # ถ้าเซฟลง DB ผ่านปุ๊บ ค่อยเอารูปปกขึ้น S3
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
    
    if params[:novel][:genres].present?
      novel.genres = sanitize_genres(params[:novel][:genres])
    end
    
    # ถ้ามีการส่งรูปปกใหม่มา โยนทับไฟล์เดิมได้เลย
    if params[:cover_content].present?
      novel.cover_path = upload_cover_to_s3(novel, params[:cover_content])
    end

    if novel.save()
      render(json: novel)
    else
      render(json: { errors: novel.errors.full_messages }, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "You don't have permission to update this novel" }, status: :forbidden)
  end

  def show()
    novel = Novel.find(params[:id])

    render(json: {
      id: novel.id,
      title: novel.title,
      pen_name: novel.user.pen_name,
      description: novel.description,
      genres: novel.genres, # ส่งหมวดหมู่กลับไปโชว์ด้วย
      cover_path: novel.cover_path # ส่งที่อยู่รูปปกกลับไปโชว์ด้วย
    }, status: :ok)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "ไม่พบนิยาย" }, status: :not_found)
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
    params.require(:novel).permit(:title, :description, genres: [])
  end

  # ฟังก์ชันกรอง
  def sanitize_genres(genres_array)
    return [] unless genres_array.is_a?(Array)
    # เก็บเฉพาะหมวดหมู่ที่อยู่ใน ALLOWED_GENRES เท่านั้น ตัวไหนพิมพ์มามั่วๆ โดนเตะทิ้งหมด
    genres_array.map(&:downcase).select { |g| ALLOWED_GENRES.include?(g) }
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
  def upload_cover_to_s3(novel, file_content)
    begin
      @s3_client.create_bucket(bucket: @bucket_name)
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou, Aws::S3::Errors::BucketAlreadyExists
    end

    # ตั้งชื่อไฟล์รูปปกเป็น /covers/novel_id.png
    object_key = "covers/#{novel.id}.png"

    @s3_client.put_object(
      bucket: @bucket_name,
      key: object_key,
      body: file_content
    )

    return "/#{@bucket_name}/#{object_key}"
  end

  # ลบรูปปกใน S3 ทิ้ง
  def delete_cover_from_s3(novel)
    object_key = "covers/#{novel.id}.png"
    @s3_client.delete_object(bucket: @bucket_name, key: object_key)
  end
end