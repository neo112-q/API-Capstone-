class Api::V1::ChaptersController < ::ApplicationController
  # บังคับว่าต้องมี Token นะ
  before_action(:authorize_request, except: [ :index, :show ])

  before_action(:set_optional_user, only: [ :show ])
  # เตรียมเชื่อมต่อ S3 รอไว้เลย จะได้เรียกใช้ได้ทั้งตอน C และ D
  before_action(:set_s3_client)

  # ดูรายชื่อตอนทั้งหมดของนิยาย
  def index
    novel = Novel.find(params[:novel_id])
    chapters = novel.chapters.order(:chapter_no)

    result = chapters.map do |ch|
      object_key = "novel/#{novel.user_id}/#{novel.id}/#{ch.chapter_no}.txt"

      begin
        content = @s3_client.get_object(bucket: @bucket_name, key: object_key).body.read
      rescue Aws::S3::Errors::NoSuchKey
        content = "เนื้อหาว่างเปล่า"
      end
      {
        id: ch.id,
        chapter_no: ch.chapter_no,
        title: ch.title,
        content: content
      }
    end

    render(json: result)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "หานิยายไม่เจอ" }, status: :not_found)
  end

  def create
    # หานิยายก่อน
    novel = @current_user.novels.find(params[:novel_id])

    # เตรียมนิยายลง Database
    chapter = novel.chapters.build(
      chapter_no: params[:chapter_no],
      title: params[:title]
    )

    if chapter.save()
      # พอเซฟลง DB ผ่านปุ๊บ ให้เอาเนื้อหาโยนให้ S3
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

  def update
    novel = @current_user.novels.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:id])

    if params[:title].present?
      chapter.update(title: params[:title])
    end

    if params[:content].present?
      upload_to_s3(novel, chapter, params[:content])
    end

    render(json: {
      message: "อัปเดตตอนที่ #{chapter.chapter_no} เรียบร้อย!",
      chapter: chapter
    }, status: :ok)

  rescue ActiveRecord::RecordNotFound
    render(json: { error: "หานิยายไม่เจอ หรือไม่พบตอนที่ต้องการแก้ไข" }, status: :not_found)
  end

  # ถ้าติดเหรียญต้องเช็คก่อน
  def show
    novel = Novel.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:id])
    is_owner = @current_user ? (novel.user_id == @current_user.id) : false
    is_free = (!novel.is_premium || chapter.price == 0)
    has_unlocked = @current_user ? UnlockedChapter.exists?(user: @current_user, chapter: chapter) : false
    chapter.increment!(:view_count)
    chapter.novel.increment!(:view_count)

    # ดักคนเนียน
    if !is_owner && !is_free && !has_unlocked
      return render(json: {
        message: "ตอนนี้ติดเหรียญ กรุณาปลดล็อค",
        locked: true,
        price: chapter.price
      }, status: :payment_required)
    end

    object_key = "novel/#{novel.user_id}/#{novel.id}/#{chapter.chapter_no}.txt"
    begin
      content = @s3_client.get_object(bucket: @bucket_name, key: object_key).body.read
    rescue Aws::S3::Errors::NoSuchKey
      content = "ไม่พบเนื้อหาในไฟล์ S3"
    end

    # บันทึกประวัติการอ่าน
    if @current_user
      history = @current_user.reading_histories.find_or_initialize_by(novel_id: novel.id)
      history.chapter_no = chapter.chapter_no
      history.save
    end

    # ส่ง JSON กลับไปพร้อมเนื้อหา
    render(json: { chapter: chapter, content: content, locked: false }, status: :ok)
  end

  # Pessimistic Locking
  def unlock
    novel = Novel.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:id])

    return render(json: { error: "ตอนนี้อ่านฟรี!" }, status: :bad_request) if !novel.is_premium || chapter.price == 0
    return render(json: { error: "คุณปลดล็อคแล้ว!" }, status: :bad_request) if UnlockedChapter.exists?(user: @current_user, chapter: chapter)

    # ล็อคเงิน User ไม่ให้คนกดย้ำ ๆ เพื่อปั๊มยอดได้
    ActiveRecord::Base.transaction do
      @current_user.lock!

      if @current_user.coin_balance >= chapter.price
        @current_user.coin_balance -= chapter.price
        @current_user.save!

        UnlockedChapter.create!(user: @current_user, chapter: chapter, price_paid: chapter.price)
      else
        raise ActiveRecord::Rollback # เงินไม่พอ สั่งตีกลับทั้งหมด
      end
    end

    if UnlockedChapter.exists?(user: @current_user, chapter: chapter)
      render(json: { message: "ปลดล็อคสำเร็จ!", balance: @current_user.coin_balance }, status: :ok)
    else
      render(json: { error: "เหรียญไม่พอ กรุณาเติมเงิน" }, status: :payment_required)
    end
  end

  # ลบและขยับที่เหลือขึ้นมา
  def destroy
    novel = @current_user.novels.find(params[:novel_id])
    chapter_to_delete = novel.chapters.find_by!(chapter_no: params[:id])
    deleted_no = chapter_to_delete.chapter_no

    # ลบไฟล์ต้นฉบับใน S3 ก่อน
    delete_from_s3(novel, chapter_to_delete)

    chapter_to_delete.destroy()

    # ดึงตอนที่เหลือมาขยับ
    remaining_chapters = novel.chapters.where("chapter_no > ?", deleted_no).order(:chapter_no)

    remaining_chapters.each do |ch|
      old_no = ch.chapter_no
      new_no = old_no - 1

      # เปลี่ยนชื่อไฟล์ใน S3
      rename_s3_file(novel, old_no, new_no)

      # อัปเลขตอนใหม่
      ch.update_columns(chapter_no: new_no)
    end

    render(json: { message: "ลบตอนที่ #{deleted_no} และจัดลำดับตอนใหม่เรียบร้อย" }, status: :ok)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "หานิยายไม่เจอ หรือไม่พบตอนที่ระบุ" }, status: :not_found)
  end

  private

  def set_optional_user
    header = request.headers['Authorization']
    token = header.split(' ').last if header

    if token.present?
      begin
        decoded = JsonWebToken.decode(token: token)

        user_id = decoded[:user_id] || decoded["user_id"] 
        @current_user = User.find(user_id)
        novel = Novel.find(params[:novel_id])
        chapter = novel.chapters.find_by!(chapter_no: params[:id])
        history = @current_user.reading_histories.find_or_initialize_by(novel_id: novel.id)
        history.chapter_no = chapter.chapter_no
        history.save

      rescue => e
        @current_user = nil
      end
    else
      @current_user = nil
    end
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

  def upload_to_s3(novel, chapter, text_content)
    begin
      @s3_client.create_bucket(bucket: @bucket_name)
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou, Aws::S3::Errors::BucketAlreadyExists
    end

    object_key = "novel/#{novel.user_id}/#{novel.id}/#{chapter.chapter_no}.txt"

    @s3_client.put_object(
      bucket: @bucket_name,
      key: object_key,
      body: text_content
    )

    "/#{@bucket_name}/#{object_key}"
  end

  def delete_from_s3(novel, chapter)
    object_key = "novel/#{novel.user_id}/#{novel.id}/#{chapter.chapter_no}.txt"
    @s3_client.delete_object(bucket: @bucket_name, key: object_key)
  end

  def rename_s3_file(novel, old_no, new_no)
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
