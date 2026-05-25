class Api::V1::ChaptersController < ::ApplicationController
  before_action :authorize_request, except: [:index]
  before_action -> { authorize_request(optional: true) }, only: [:show]
  before_action :set_s3_client

  # GET /api/v1/novels/:novel_id/chapters
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
        price: ch.price || 0,
        free_date: ch.free_date&.iso8601  # ✅ ส่งเป็น ISO 8601 พร้อม timezone
      }
    end

    render(json: result)
  end

  # POST /api/v1/novels/:novel_id/chapters
  def create()
    novel = @current_user.novels.find(params[:novel_id])

    actual_price = params[:early_access_price].to_i > 0 ? params[:early_access_price] : params[:price]

    # ✅ ใช้ normalize_free_date ที่ถูกต้อง
    free_date = normalize_free_date(params[:free_date])

    chapter = novel.chapters.build(
      chapter_no: params[:chapter_no],
      title: params[:title],
      price: actual_price || 0,
      free_date: free_date
    )

    if chapter.save()
      content = params[:content] || ""
      file_path = upload_to_s3(novel, chapter, content)

      render(json: {
        message: "บันทึกตอนใหม่ และอัปโหลดขึ้น S3 สำเร็จแล้ว",
        s3_path: file_path,
        chapter: chapter.as_json.merge(free_date: chapter.free_date&.iso8601)
      }, status: :created)
    else
      render(json: { errors: chapter.errors.full_messages }, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "หานิยายไม่เจอ หรือคุณไม่ใช่เจ้าของนิยายเรื่องนี้" }, status: :forbidden)
  end

  # PATCH/PUT /api/v1/novels/:novel_id/chapters/:id
  def update()
    novel = @current_user.novels.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:id])

    updates = {}
    updates[:title] = params[:title] if params.key?(:title)
    
    if params.key?(:free_date)
      # ✅ ใช้ normalize_free_date ที่ถูกต้อง
      updates[:free_date] = normalize_free_date(params[:free_date])
    end

    if params.key?(:early_access_price) && params[:early_access_price].to_i > 0
      updates[:price] = params[:early_access_price]
    elsif params.key?(:price)
      updates[:price] = params[:price]
    end

    chapter.update(updates)

    if params[:content].present?
      upload_to_s3(novel, chapter, params[:content])
    end

    render(json: {
      message: "อัปเดตตอนที่ #{chapter.chapter_no} เรียบร้อย!",
      chapter: chapter.as_json.merge(free_date: chapter.free_date&.iso8601)
    }, status: :ok)

  rescue ActiveRecord::RecordNotFound
    render(json: { error: "หานิยายไม่เจอ หรือไม่พบตอนที่ต้องการแก้ไข" }, status: :not_found)
  end

  # GET /api/v1/novels/:novel_id/chapters/:id
  def show()
    novel = Novel.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:id])
    
    is_owner = @current_user && novel.user_id == @current_user.id
    has_purchased_novel = @current_user && Purchase.exists?(user: @current_user, novel: novel)
    has_unlocked = @current_user && UnlockedChapter.exists?(user: @current_user, novel_id: novel.id, chapter_no: chapter.chapter_no)
    
    case novel.pricing_model
    when 'free'
      is_free_chapter = true
    when 'one_time'
      is_free_chapter = (is_owner || has_purchased_novel)
    when 'per_chapter'
      if chapter.chapter_no == 1 && (chapter.price.nil? || chapter.price == 0)
        is_free_chapter = true
      else
        is_free_chapter = has_unlocked
      end
    when 'early_access'
      # ✅ เช็ค free_date ให้ถูกต้อง
      if chapter.free_date.present?
        if Time.current >= chapter.free_date
          is_free_chapter = true
        else
          is_free_chapter = has_unlocked
        end
      else
        if chapter.price.nil? || chapter.price.to_i == 0
          is_free_chapter = true
        else
          is_free_chapter = has_unlocked
        end
      end
    else
      is_free_chapter = chapter.price.nil? || chapter.price == 0
    end
    
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
        free_date: chapter.free_date&.iso8601
      }, status: :ok)
    end
    
    if novel.pricing_model == 'one_time' && novel.price > 0 && !has_purchased_novel && !is_owner
      return render(json: { 
        locked: true, 
        requires_purchase: true,
        price: novel.price,
        message: "กรุณาซื้อนิยายก่อนราคา #{novel.price} เหรียญ"
      }, status: :payment_required)
    end
    
    if !is_free_chapter && !has_unlocked
      price_to_show = chapter.price || 0
      return render(json: { 
        locked: true, 
        requires_purchase: false,
        price: price_to_show,
        message: "ปลดล็อคตอนนี้ราคา #{price_to_show} เหรียญ"
      }, status: :payment_required)
    end

    render(json: { error: "ไม่สามารถเข้าถึงตอนนี้ได้" }, status: :forbidden)
  end

  # POST /api/v1/novels/:novel_id/chapters/:id/unlock
  def unlock()
    novel = Novel.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:id])

    price_to_pay = chapter.price || 0

    return render(json: { error: "ตอนนี้อ่านฟรี!" }, status: :bad_request) if !novel.is_premium || price_to_pay == 0
    
    if UnlockedChapter.exists?(user_id: @current_user.id, novel_id: novel.id, chapter_no: chapter.chapter_no)
      return render(json: { error: "คุณปลดล็อคแล้ว!" }, status: :bad_request)
    end

    ActiveRecord::Base.transaction do
      @current_user.lock!

      if @current_user.coin_balance >= price_to_pay
        @current_user.coin_balance -= price_to_pay
        @current_user.save!

        UnlockedChapter.create!(
          user_id: @current_user.id,
          novel_id: novel.id,
          chapter_id: chapter.id,
          chapter_no: chapter.chapter_no,
          price_paid: price_to_pay
        )

        author = novel.user
        author_revenue = (price_to_pay * 0.6).to_i
        author.update!(earnings_balance: author.earnings_balance + author_revenue) if author_revenue > 0
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
  def destroy()
    novel = @current_user.novels.find(params[:novel_id])
    chapter_to_delete = novel.chapters.find_by!(chapter_no: params[:id])
    deleted_no = chapter_to_delete.chapter_no

    delete_from_s3(novel, chapter_to_delete)
    chapter_to_delete.destroy
    
    remaining_chapters = novel.chapters.where("chapter_no > ?", deleted_no).order(:chapter_no)

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

  # ✅ เมธอด normalize วันที่ที่ถูกต้อง
  def normalize_free_date(date_string)
    return nil if date_string.blank?
    
    date_string = date_string.to_s.strip
    
    begin
      # ✅ ใช้ Time.zone.parse เพื่อแปลง local time + timezone
      # สมมติว่า frontend ส่ง local datetime มา (Asia/Bangkok)
      Time.use_zone('Asia/Bangkok') do
        parsed = Time.zone.parse(date_string)
        return parsed if parsed.present?
      end
      
      # fallback
      Time.zone.parse(date_string)
    rescue => e
      Rails.logger.error "Error parsing date: #{date_string}, error: #{e.message}"
      nil
    end
  end

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

  def load_chapter_content(novel, chapter)
    object_key = "novel/#{novel.user_id}/#{novel.id}/#{chapter.chapter_no}.txt"
    
    begin
      content = @s3_client.get_object(bucket: @bucket_name, key: object_key).body.read
    rescue Aws::S3::Errors::NoSuchKey
      content = ""
    end
    
    content
  end

  def set_s3_client()
    @s3_client = Aws::S3::Client.new(
      endpoint: ENV.fetch('MINIO_ENDPOINT', 'http://host.docker.internal:9000'),
      access_key_id: ENV.fetch('MINIO_ACCESS_KEY', 'admin'),
      secret_access_key: ENV.fetch('MINIO_SECRET_KEY', 'password123'),
      region: "us-east-1",
      force_path_style: true
    )
    @bucket_name = "novels-bucket"
  end

    # แก้ไข upload_to_s3
  def upload_to_s3(novel, chapter, text_content)
    begin
      @s3_client.create_bucket(bucket: @bucket_name)
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou, Aws::S3::Errors::BucketAlreadyExists
    end

    # ✅ เปลี่ยนจาก @current_user.id เป็น novel.user_id
    object_key = "novel/#{novel.user_id}/#{novel.id}/#{chapter.chapter_no}.txt"

    @s3_client.put_object(
      bucket: @bucket_name,
      key: object_key,
      body: text_content
    )

    return "/#{@bucket_name}/#{object_key}"
  end

  # แก้ไข delete_from_s3
  def delete_from_s3(novel, chapter)
    # ✅ เปลี่ยนจาก @current_user.id เป็น novel.user_id
    object_key = "novel/#{novel.user_id}/#{novel.id}/#{chapter.chapter_no}.txt"
    @s3_client.delete_object(bucket: @bucket_name, key: object_key)
  end

  # แก้ไข rename_s3_file
  def rename_s3_file(novel, old_no, new_no)
    # ✅ เปลี่ยนจาก @current_user.id เป็น novel.user_id
    old_key = "novel/#{novel.user_id}/#{novel.id}/#{old_no}.txt"
    new_key = "novel/#{novel.user_id}/#{novel.id}/#{new_no}.txt"

    @s3_client.copy_object(
      bucket: @bucket_name,
      copy_source: "#{@bucket_name}/#{old_key}",
      key: new_key
    )
    @s3_client.delete_object(bucket: @bucket_name, key: old_key)
  end
end