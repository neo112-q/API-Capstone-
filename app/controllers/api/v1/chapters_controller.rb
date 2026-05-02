class Api::V1::ChaptersController < ::ApplicationController
  before_action :authorize_request, except: [:index]
  before_action -> { authorize_request(optional: true) }, only: [:show]
  before_action :set_s3_client

  # GET /api/v1/novels/:novel_id/chapters
  # ดึงรายการตอนทั้งหมดของนิยายเรื่องหนึ่ง
  def index()
    novel = Novel.find(params[:novel_id])
    chapters = novel.chapters.order(:chapter_no)

    result = chapters.map do |ch|
      {
        id: ch.id,
        chapter_no: ch.chapter_no,
        title: ch.title,
        content: load_chapter_content(novel, ch),
        view_count: ch.view_count,
        like_count: ch.likes_count,
        is_liked: @current_user ? ch.is_liked_by?(@current_user) : false,
        price: ch.price || 0
      }
    end

    render(json: result)
  end

  # POST /api/v1/novels/:novel_id/chapters
  # สร้างตอนใหม่ พร้อมอัปโหลดเนื้อหาขึ้น S3
  def create()
    novel = @current_user.novels.find(params[:novel_id])

    chapter = novel.chapters.build(
      chapter_no: params[:chapter_no],
      title: params[:title],
      price: params[:price] || 0
    )

    if chapter.save()
      content = params[:content] || ""
      file_path = upload_to_s3(novel, chapter, content)

      render(json: {
        message: "บันทึกตอนใหม่ และอัปโหลดขึ้น S3 สำเร็จแล้ว",
        s3_path: file_path,
        chapter: chapter
      }, status: :created)
    else
      render(json: { errors: chapter.errors.full_messages }, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "หานิยายไม่เจอ หรือคุณไม่ใช่เจ้าของนิยายเรื่องนี้" }, status: :forbidden)
  end

  # PATCH/PUT /api/v1/novels/:novel_id/chapters/:id
  # แก้ไขชื่อตอน หรืออัปโหลดเนื้อหาใหม่
  def update()
    novel = @current_user.novels.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:id])

    if params[:title].present?
      chapter.update(title: params[:title])
    end

    if params[:price].present?
      chapter.update(price: params[:price])
    end

    if params[:content].present?
      upload_to_s3(novel, chapter, params[:content])
    end

    if params[:free_date].present?
      chapter.update(free_date: params[:free_date])
    end

    render(json: {
      message: "อัปเดตตอนที่ #{chapter.chapter_no} เรียบร้อย!",
      chapter: chapter
    }, status: :ok)

  rescue ActiveRecord::RecordNotFound
    render(json: { error: "หานิยายไม่เจอ หรือไม่พบตอนที่ต้องการแก้ไข" }, status: :not_found)
  end

  # GET /api/v1/novels/:novel_id/chapters/:id
  # อ่านเนื้อหาตอน (เช็คสิทธิ์การเข้าถ่อน)
  def show()
    novel = Novel.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:id])
    
    is_owner = @current_user && novel.user_id == @current_user.id
    has_purchased_novel = @current_user && Purchase.exists?(user: @current_user, novel: novel)
    has_unlocked = @current_user && UnlockedChapter.exists?(user: @current_user, novel_id: novel.id, chapter_no: chapter.chapter_no)
    
    # ✅ ตรวจสอบ pricing model
    case novel.pricing_model
    when 'free'
      # อ่านได้ทุกตอนฟรี
      is_free_chapter = true
      
    when 'one_time'
      # ซื้อทั้งเล่ม: ถ้าซื้อแล้วหรือเป็นเจ้าของ อ่านได้
      if is_owner || has_purchased_novel
        is_free_chapter = true
      else
        is_free_chapter = false
      end
      
    when 'per_chapter'
      # ซื้อทีละตอน: ตอนที่ 1 ฟรีเสมอ, ตอนอื่นต้องปลดล็อค
      if chapter.chapter_no == 1
        is_free_chapter = true
      else
        is_free_chapter = has_unlocked
      end
      
    when 'early_access'
      # อ่านล่วงหน้า: เช็คว่าถึงวันปลดล็อคหรือยัง
      if chapter.free_date.present? && Time.current >= chapter.free_date
        is_free_chapter = true  # หมดเขต early access แล้ว อ่านฟรี
      else
        is_free_chapter = has_unlocked  # ยังอยู่ในช่วง early access ต้องจ่าย
      end
      
    else
      is_free_chapter = chapter.price.nil? || chapter.price == 0
    end
    
    # ✅ เงื่อนไขการเข้าถึง
    if is_owner || is_free_chapter || has_purchased_novel || has_unlocked
      record_chapter_view(chapter)
      content = load_chapter_content(novel, chapter)
      like_count = ChapterLike.where(novel_id: novel.id, chapter_no: chapter.chapter_no).count
      is_liked = @current_user ? ChapterLike.exists?(user_id: @current_user.id, novel_id: novel.id, chapter_no: chapter.chapter_no) : false

      return render(json: { 
        chapter: chapter, 
        content: content,
        view_count: chapter.view_count,
        like_count: like_count,
        is_liked: is_liked,
        locked: false,
        price: chapter.price || 0,
        free_date: chapter.free_date  # ✅ ส่งกลับไปด้วย
      }, status: :ok)
    end
    
    # ✅ กรณีต้องจ่าย
    if novel.pricing_model == 'one_time' && novel.price > 0 && !has_purchased_novel && !is_owner
      return render(json: { 
        locked: true, 
        requires_purchase: true,
        price: novel.price,
        message: "กรุณาซื้อนิยายก่อนราคา #{novel.price} เหรียญ"
      }, status: :payment_required)
    end
    
    if !is_free_chapter && !has_unlocked
      price_to_show = novel.pricing_model == 'early_access' ? (chapter.price || novel.early_access_price) : chapter.price
      return render(json: { 
        locked: true, 
        requires_purchase: false,
        price: price_to_show || 0,
        message: "ปลดล็อคตอนนี้ราคา #{price_to_show} เหรียญ"
      }, status: :payment_required)
    end

    render(json: { error: "ไม่สามารถเข้าถึงตอนนี้ได้" }, status: :forbidden)
  end

  # POST /api/v1/novels/:novel_id/chapters/:id/unlock
  def unlock()
    novel = Novel.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:id])

    return render(json: { error: "ตอนนี้อ่านฟรี!" }, status: :bad_request) if !novel.is_premium || chapter.price == 0
    
    # ✅ แก้ไขตรงนี้
    if UnlockedChapter.exists?(user_id: @current_user.id, novel_id: novel.id, chapter_no: chapter.chapter_no)
      return render(json: { error: "คุณปลดล็อคแล้ว!" }, status: :bad_request)
    end

    ActiveRecord::Base.transaction do
      @current_user.lock!

      if @current_user.coin_balance >= chapter.price
        @current_user.coin_balance -= chapter.price
        @current_user.save!

        # ✅ สร้างโดยใช้ novel_id และ chapter_no
        UnlockedChapter.create!(
          user_id: @current_user.id,
          novel_id: novel.id,
          chapter_no: chapter.chapter_no,
          price_paid: chapter.price
        )
      else
        raise ActiveRecord::Rollback
      end
    end

    if UnlockedChapter.exists?(user_id: @current_user.id, novel_id: novel.id, chapter_no: chapter.chapter_no)
      render(json: { message: "ปลดล็อคสำเร็จ!", balance: @current_user.reload.coin_balance }, status: :ok)
    else
      render(json: { error: "เหรียญไม่พอ กรุณาเติมเงิน" }, status: :payment_required)
    end
  end

  # DELETE /api/v1/novels/:novel_id/chapters/:id
  # ลบตอน และขยับเลขตอนที่เหลือให้ถูกต้อง
  def destroy()
    novel = @current_user.novels.find(params[:novel_id])
    chapter_to_delete = novel.chapters.find_by!(chapter_no: params[:id])
    deleted_no = chapter_to_delete.chapter_no

    # ลบไฟล์ใน S3 ก่อน
    delete_from_s3(novel, chapter_to_delete)
    
    # ลบข้อมูลใน Database
    chapter_to_delete.destroy
    
    # ดึงตอนทั้งหมดที่มีเลขมากกว่าตอนที่ลบ
    remaining_chapters = novel.chapters.where("chapter_no > ?", deleted_no).order(:chapter_no)

    # ขยับเลขตอนและrenameไฟล์ใน S3
    remaining_chapters.each do |ch|
      old_no = ch.chapter_no
      new_no = old_no - 1

      rename_s3_file(novel, old_no, new_no)
      ch.update_columns(chapter_no: new_no)
    end

    render(json: { message: "ลบตอนที่ #{deleted_no} และจัดลำดับตอนใหม่เรียบร้อย" }, status: :ok)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "หานิยายไม่เจอ หรือไม่พบตอนที่ระบุ" }, status: :not_found)
  end

  private

  # บันทึกสถิติการเข้าชม (ป้องกันการนับซ้ำ)
  def record_chapter_view(chapter)
    if @current_user
      existing = ChapterView.find_by(
        novel_id: chapter.novel_id,
        chapter_no: chapter.chapter_no,
        user_id: @current_user.id
      )
      
      unless existing
        ChapterView.create!(
          novel_id: chapter.novel_id,
          chapter_no: chapter.chapter_no,
          user_id: @current_user.id,
          viewed_at: Time.current
        )
      end
    else
      session_id = request.session.id.to_s
      
      existing = ChapterView.find_by(
        novel_id: chapter.novel_id,
        chapter_no: chapter.chapter_no,
        session_id: session_id
      )
      
      unless existing
        ChapterView.create!(
          novel_id: chapter.novel_id,
          chapter_no: chapter.chapter_no,
          session_id: session_id,
          viewed_at: Time.current
        )
      end
    end
  end

  # โหลดเนื้อหาตอนจาก S3
  def load_chapter_content(novel, chapter)
    object_key = "novel/#{novel.user_id}/#{novel.id}/#{chapter.chapter_no}.txt"
    
    begin
      content = @s3_client.get_object(bucket: @bucket_name, key: object_key).body.read
    rescue Aws::S3::Errors::NoSuchKey
      content = ""
    end
    
    content
  end

  # ตั้งค่า S3 Client (เชื่อมต่อ MinIO)
  def set_s3_client()
    @s3_client = Aws::S3::Client.new(
      endpoint: ENV.fetch('MINIO_ENDPOINT', 'http://host.docker.internal:9000'),
      access_key_id: "admin_o",
      secret_access_key: "password_o123",
      region: "us-east-1",
      force_path_style: true
    )
    @bucket_name = "novels-bucket"
  end

  # อัปโหลดเนื้อหาตอนขึ้น S3
  def upload_to_s3(novel, chapter, text_content)
    begin
      @s3_client.create_bucket(bucket: @bucket_name)
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou, Aws::S3::Errors::BucketAlreadyExists
    end

    object_key = "novel/#{@current_user.id}/#{novel.id}/#{chapter.chapter_no}.txt"

    @s3_client.put_object(
      bucket: @bucket_name,
      key: object_key,
      body: text_content
    )

    return "/#{@bucket_name}/#{object_key}"
  end

  # ลบไฟล์ตอนออกจาก S3
  def delete_from_s3(novel, chapter)
    object_key = "novel/#{novel.user_id}/#{novel.id}/#{chapter.chapter_no}.txt"
    @s3_client.delete_object(bucket: @bucket_name, key: object_key)
  end

  # เปลี่ยนชื่อไฟล์ใน S3 (ใช้ตอนขยับเลข章节)
  def rename_s3_file(novel, old_no, new_no)
    old_key = "novel/#{novel.user_id}/#{novel.id}/#{old_no}.txt"
    new_key = "novel/#{novel.user_id}/#{novel.id}/#{new_no}.txt"

    # Copy ไฟล์เก่าไปชื่อใหม่
    @s3_client.copy_object(
      bucket: @bucket_name,
      copy_source: "#{@bucket_name}/#{old_key}",
      key: new_key
    )
    # ลบไฟล์เก่า
    @s3_client.delete_object(bucket: @bucket_name, key: old_key)
  end
end