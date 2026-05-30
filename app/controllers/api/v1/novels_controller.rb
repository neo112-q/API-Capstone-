require 'base64'

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
    search_query = params[:search].presence

    if search_query
      novels = search_novels(search_query)
    else
      novels = Novel.where(status: :published).order(updated_at: :desc).includes(:genres)
    end

    novel_ids = novels.map(&:id)

    likes_by_novel = ChapterLike.where(novel_id: novel_ids).group(:novel_id).count
    views_by_novel = ChapterView.where(novel_id: novel_ids).group(:novel_id).count

    novels_with_views = novels.map do |novel|
      novel.as_json(include: :genres).merge(
        view_count: views_by_novel[novel.id] || 0,
        like_count: likes_by_novel[novel.id] || 0,
        tags: novel.tags || [],
        language: novel.language
      )
    end

    render(json: novels_with_views)
  end

  # สร้างนิยาย ดึง user_id จาก Token อัตโนมัติ
  def create()
    genre_objects = Genre.where(name: sanitize_genres(params[:novel][:genres]))
    
    pen_name = params[:novel][:pen_name].presence || @current_user.username
    
    novel = @current_user.novels.build(
      title: params[:novel][:title],
      description: params[:novel][:description],
      pen_name: pen_name,
      genres: genre_objects,
      status: params[:novel][:status] || 'draft',
      is_premium: params[:novel][:is_premium] || false,
      price: params[:novel][:price] || 0,
      pricing_model: params[:novel][:pricing_model] || 'free',
      early_access_days: params[:novel][:early_access_days] || 7,
      per_chapter_price: params[:novel][:per_chapter_price] || 0,
      tags: params[:novel][:tags] || []
    )

    if novel.save()
      # ✅ จัดการ cover (ทั้งรูปและอีโมจิ)
      if params[:cover_content].present?
        cover_url = upload_cover_to_s3(novel, params[:cover_content])
        novel.update_columns(cover_path: cover_url)
        novel.reload
      elsif params[:cover_emoji].present?
        # ✅ ถ้าเป็นอีโมจิ ให้บันทึกเป็น string ตรงๆ
        novel.update_columns(cover_path: params[:cover_emoji])
        novel.reload
      end

      render(json: novel.as_json(only: [:id, :title, :cover_path, :tags]), status: :created)
    else
      render(json: { errors: novel.errors.full_messages }, status: :unprocessable_entity)
    end
  end

  # แก้ไขข้อมูล แก้ได้เฉพาะนิยายของตัวเองเท่านั้นนะ
  def update()
    novel = @current_user.novels.find(params[:id])
    
    # อัปเดตข้อมูลพื้นฐาน
    if params[:novel][:title].present?
      novel.title = params[:novel][:title]
    end
    
    if params[:novel][:description].present?
      novel.description = params[:novel][:description]
    end

    if params[:novel][:pen_name].present?
      novel.pen_name = params[:novel][:pen_name]
    end
    
    if params[:novel][:status].present?
      novel.status = params[:novel][:status]
    end

    if params[:novel][:genres].present?
      novel.genres = Genre.where(name: params[:novel][:genres])
    end

    if params[:novel][:is_premium].present?
      novel.is_premium = params[:novel][:is_premium]
    end

    if params[:novel][:price].present?
      novel.price = params[:novel][:price]
    end

    if params[:novel][:pricing_model].present?
      novel.pricing_model = params[:novel][:pricing_model]
    end

    if params[:novel][:early_access_days].present?
      novel.early_access_days = params[:novel][:early_access_days]
    end

    if params[:novel][:per_chapter_price].present?
      novel.per_chapter_price = params[:novel][:per_chapter_price]
    end

    if params[:novel][:tags].present?
      novel.tags = params[:novel][:tags]
    end

    if params[:cover_content].present?
      novel.cover_path = upload_cover_to_s3(novel, params[:cover_content])
    elsif params[:cover_emoji].present?
      novel.cover_path = params[:cover_emoji]
    end

    if novel.save()
      # Refresh language from chapter titles + description on save
      if novel.status.in?(['published', 'draft', 'writing'])
        all_text = [novel.description, novel.title, novel.chapters.pluck(:title).join(' ')].join(' ')
        detected = LanguageDetector.detect(all_text)
        novel.update_columns(language: detected) if detected
      end
      render(json: novel.as_json(include: :genres).merge(tags: novel.tags, language: novel.language), status: :ok)
    else
      render(json: { errors: novel.errors.full_messages }, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "You don't have permission to update this novel" }, status: :forbidden)
  end

  def show()
    authorize_request(optional: true)
    novel = Novel.find(params[:id])
    
    has_purchased = false
    if @current_user
      has_purchased = Purchase.exists?(user: @current_user, novel: novel)
    end

    total_likes = ChapterLike.where(novel_id: novel.id).count
    
    # ✅ จัดการ cover_path ให้ส่งกลับไป frontend ให้ถูกต้อง
    cover_path_value = novel.cover_path
    # ถ้า cover_path เป็นอีโมจิ (ความยาวน้อยกว่า 5 ตัว และไม่มี http หรือ /)
    if cover_path_value.present? && cover_path_value.length <= 5 && !cover_path_value.include?('http') && !cover_path_value.include?('/')
      # ส่งอีโมจิไปเลย
      cover_path_value = cover_path_value
    end
    
    render(json: {
      id: novel.id,
      title: novel.title,
      pen_name: novel.pen_name,
      description: novel.description,
      genres: novel.genres,
      tags: novel.tags || [],
        language: novel.language,
      cover_path: cover_path_value,  
      view_count: novel.total_views(),
      like_count: total_likes,
      follow_count: novel.follows.count,
      is_followed: @current_user ? novel.follows.exists?(user: @current_user) : false,
      price: novel.price || 0,              
      is_premium: novel.is_premium || false,     
      user_id: novel.user_id,                     
      has_purchased: has_purchased,
      pricing_model: novel.pricing_model || 'free',
      early_access_days: novel.early_access_days || 7,
      per_chapter_price: novel.per_chapter_price || 0,
      status: novel.status || 'draft',
      language: novel.language
    }, status: :ok)
  end

  def my_novels()
    begin
      novels = @current_user.novels.order(updated_at: :desc).includes(:genres)
      novel_ids = novels.map(&:id)

      likes_by_novel = ChapterLike.where(novel_id: novel_ids).group(:novel_id).count
      views_by_novel = ChapterView.where(novel_id: novel_ids).group(:novel_id).count
      chapter_counts = Chapter.where(novel_id: novel_ids).group(:novel_id).count

      result = novels.map do |novel|
        {
          id: novel.id,
          title: novel.title,
          description: novel.description,
          pen_name: novel.pen_name,
          cover_path: novel.cover_path,
          status: novel.status,
          chapters_count: chapter_counts[novel.id] || 0,
          views: views_by_novel[novel.id] || 0,
          likes: likes_by_novel[novel.id] || 0,
          created_at: novel.created_at,
          updated_at: novel.updated_at,
          genres: novel.genres.as_json(only: [:id, :name]),
          tags: novel.tags || [],
        language: novel.language
        }
      end

      render(json: result, status: :ok)
    rescue => e
      puts "Error in my_novels: #{e.message}"
      render(json: { error: e.message }, status: :internal_server_error)
    end
  end

  def destroy()
    novel = @current_user.novels.find(params[:id])

    ActiveRecord::Base.transaction do
      UnlockedChapter.where(novel_id: novel.id).delete_all
      ChapterLike.where(novel_id: novel.id).delete_all
      ChapterView.where(novel_id: novel.id).delete_all
      ReadingHistory.where(novel_id: novel.id).delete_all
      Follow.where(novel_id: novel.id).delete_all
      Purchase.where(novel_id: novel.id).delete_all
      Comment.where(novel_id: novel.id).delete_all
      NovelGenre.where(novel_id: novel.id).delete_all
      Chapter.where(novel_id: novel.id).delete_all
      Like.where(likeable_type: 'Novel', likeable_id: novel.id).delete_all
      novel.destroy!
    end

    delete_cover_from_s3(novel) if image_cover?(novel.cover_path)

    Thread.new do
      CapstoneAiService.delete_novel(novel.id)
    end

    render(json: { message: "Your novel has been deleted" }, status: :ok)

  rescue ActiveRecord::RecordNotFound
    render(json: { error: "You don't have permission to delete this novel" }, status: :forbidden)
  rescue => e
    Rails.logger.error "Delete novel error: #{e.message}"
    render(json: { error: e.message }, status: :internal_server_error)
  end

  private

  def search_novels(query)
    capstone_results = CapstoneAiService.search_by_keyword(query, 20)
    if capstone_results.any?
      novel_ids = capstone_results.map { |r| r[:novel_id] }.uniq.first(20)
      novels = Novel.where(id: novel_ids, status: :published).includes(:genres)
      sorted = novels.sort_by { |n| novel_ids.index(n.id) }
      return sorted if sorted.any?
    end

    # Fallback to ILIKE search
    Novel.where(status: :published)
         .where("title ILIKE :q OR pen_name ILIKE :q OR description ILIKE :q", q: "%#{query}%")
         .order(updated_at: :desc)
         .includes(:genres)
         .limit(20)
  end

  def novel_params()
    params.require(:novel).permit(:title, :description, :cover_path)
  end

  def sanitize_genres(genres_array)
    return [] unless genres_array.is_a?(Array)
    allowed_from_db = Genre.pluck(:name).map(&:downcase)
    genres_array.map(&:downcase).select { |g| allowed_from_db.include?(g) }
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
      content_type: "image/png",
      content_disposition: "inline"
    )

    return "#{ENV.fetch('API_BASE_URL', 'http://naphon.ddns.net:3000')}/api/v1/images/#{object_key}"
  end

  def delete_cover_from_s3(novel)
    return unless image_cover?(novel.cover_path)
    begin
      object_key = "covers/#{novel.id}.png"
      @s3_client.delete_object(bucket: @bucket_name, key: object_key)
    rescue => e
      Rails.logger.error "S3 delete cover error: #{e.message}"
    end
  end

  def image_cover?(path)
    path.present? && (path.start_with?('http://', 'https://') || path.include?('/'))
  end
end