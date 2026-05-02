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
    novels = Novel.where(status: :published).order(updated_at: :desc)
    
    novels_with_views = novels.map do |novel|
      total_likes = ChapterLike.where(novel_id: novel.id).count
      novel.as_json(include: :genres).merge(
        view_count: novel.total_views,
        like_count: total_likes
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
      is_premium: params[:novel][:is_premium] || false,  # ✅ เพิ่ม
      price: params[:novel][:price] || 0,
      pricing_model: params[:novel][:pricing_model] || 'free',
      early_access_days: params[:novel][:early_access_days] || 7,
      per_chapter_price: params[:novel][:per_chapter_price] || 0
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
    
    if params[:novel][:title].present?
      novel.title = params[:novel][:title]
    end
    
    if params[:novel][:description].present?
      novel.description = params[:novel][:description]
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

    # ✅ เพิ่ม 3 บรรทัดนี้ (สำคัญมาก!)
    if params[:novel][:pricing_model].present?
      novel.pricing_model = params[:novel][:pricing_model]
    end

    if params[:novel][:early_access_days].present?
      novel.early_access_days = params[:novel][:early_access_days]
    end

    if params[:novel][:per_chapter_price].present?
      novel.per_chapter_price = params[:novel][:per_chapter_price]
    end

    if params[:cover_content].present?
      novel.cover_path = upload_cover_to_s3(novel, params[:cover_content])
    end

    if novel.save()
      render(json: novel, include: :genres)
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
    
    render(json: {
      id: novel.id,
      title: novel.title,
      pen_name: novel.pen_name,
      description: novel.description,
      genres: novel.genres,
      cover_path: novel.cover_path,
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
      per_chapter_price: novel.per_chapter_price || 0             
    }, status: :ok)
  end

  def my_novels()
    begin
      novels = @current_user.novels.order(updated_at: :desc)
      
      result = novels.map do |novel|
        {
          id: novel.id,
          title: novel.title,
          description: novel.description,
          pen_name: novel.pen_name,
          cover_path: novel.cover_path,
          status: novel.status,
          chapters_count: novel.chapters.count,
          views: novel.total_views(),
          likes: novel.likes.count,
          created_at: novel.created_at,
          updated_at: novel.updated_at,
          genres: novel.genres.as_json(only: [:id, :name])
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
    
    # ✅ ใช้ transaction และลบด้วย SQL โดยตรง
    ActiveRecord::Base.transaction do
      # ลบข้อมูลที่เกี่ยวข้องทั้งหมด
      UnlockedChapter.where(novel_id: novel.id).delete_all
      ChapterLike.where(novel_id: novel.id).delete_all
      ChapterView.where(novel_id: novel.id).delete_all
      ReadingHistory.where(novel_id: novel.id).delete_all
      Follow.where(novel_id: novel.id).delete_all
      Purchase.where(novel_id: novel.id).delete_all
      NovelGenre.where(novel_id: novel.id).delete_all
      
      # ลบ chapters
      Chapter.where(novel_id: novel.id).delete_all
      
      # ลบ cover
      delete_cover_from_s3(novel) if novel.cover_path.present?
      
      # ลบนิยาย
      novel.destroy
    end
    
    render(json: { message: "Your novel has been deleted" }, status: :ok)
    
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "You don't have permission to delete this novel" }, status: :forbidden)
  rescue => e
    Rails.logger.error "Delete novel error: #{e.message}"
    render(json: { error: e.message }, status: :internal_server_error)
  end

  private

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
      access_key_id: "admin_o",
      secret_access_key: "password_o123",
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

    return "http://localhost:9000/#{@bucket_name}/#{object_key}"
  end

  def delete_cover_from_s3(novel)
    object_key = "covers/#{novel.id}.png"
    @s3_client.delete_object(bucket: @bucket_name, key: object_key)
  end
end