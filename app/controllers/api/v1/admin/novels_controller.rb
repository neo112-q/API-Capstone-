# app/controllers/api/v1/admin/novels_controller.rb
class Api::V1::Admin::NovelsController < ApplicationController
  before_action :authorize_request
  before_action :authorize_admin

  def index
    # ✅ สร้าง base query สำหรับกรอง
    novels = Novel.left_joins(:user)
    
    if params[:status].present?
      novels = novels.where(status: params[:status])
    end
    
    # ✅ ใช้ size แทน count (size ใช้ SQL COUNT(*) ที่ถูกต้อง)
    total = novels.size
    
    # ✅ ดึงข้อมูลพร้อม order และ select
    novels_data = novels.order(created_at: :desc)
                        .select('novels.*, users.username as author_name')
    
    render(json: {
      total: total,
      novels: novels_data.map do |novel|
        {
          id: novel.id,
          title: novel.title,
          pen_name: novel.pen_name,
          status: novel.status,
          view_count: novel.total_views || 0,
          like_count: novel.likes&.count || 0,
          created_at: novel.created_at,
          updated_at: novel.updated_at,
          user_id: novel.user_id,
          username: novel.author_name,
          cover_path: novel.cover_path,
          description: novel.description,
          genres: novel.genres.as_json(only: [:id, :name])
        }
      end
    }, status: :ok)
  end

  def update
    novel = Novel.find(params[:id])
    
    if novel.update(novel_params)
      render(json: { 
        message: "อัปเดตนิยาย #{novel.title} สำเร็จ", 
        novel: {
          id: novel.id,
          title: novel.title,
          status: novel.status
        }
      }, status: :ok)
    else
      render(json: { errors: novel.errors.full_messages }, status: :unprocessable_entity)
    end
  end

  def destroy
    novel = Novel.find(params[:id])
    
    ActiveRecord::Base.transaction do
      chapters = Chapter.where(novel_id: novel.id)
      
      # ✅ ลบ chapter_views
      ChapterView.where(novel_id: novel.id).delete_all if chapters.any?
      
      # ✅ ลบ unlocked_chapters (ถ้ามี)
      UnlockedChapter.where(novel_id: novel.id).delete_all if defined?(UnlockedChapter)
      
      # ✅ ลบ chapters ใน S3
      chapters.each do |chapter|
        delete_chapter_from_s3(novel.user_id, novel.id, chapter.chapter_no)
      end
      
      # ✅ ลบ cover ใน S3
      delete_cover_from_s3(novel.id) if novel.cover_path.present?
      
      # ✅ ลบ chapters ใน database
      Chapter.where(novel_id: novel.id).delete_all
      
      # ✅ ลบ novel
      novel.destroy!
    end
    
    render(json: { message: "ลบนิยาย #{novel.title} สำเร็จ" }, status: :ok)
  rescue => e
    Rails.logger.error("Delete novel failed: #{e.message}")
    render(json: { error: e.message }, status: :internal_server_error)
  end

  private

  def novel_params
    params.permit(:status)
  end

  def set_s3_client
    @s3_client = Aws::S3::Client.new(
      endpoint: ENV.fetch('MINIO_ENDPOINT', 'http://host.docker.internal:9000'),
      access_key_id: ENV.fetch('MINIO_ACCESS_KEY', 'admin_o'),
      secret_access_key: ENV.fetch('MINIO_SECRET_KEY', 'password_o123'),
      region: "us-east-1",
      force_path_style: true
    )
    @bucket_name = "novels-bucket"
  end

  def delete_chapter_from_s3(user_id, novel_id, chapter_no)
    set_s3_client
    object_key = "novel/#{user_id}/#{novel_id}/#{chapter_no}.txt"
    @s3_client.delete_object(bucket: @bucket_name, key: object_key)
  rescue => e
    Rails.logger.error "Failed to delete S3 object: #{e.message}"
  end

  def delete_cover_from_s3(novel_id)
    set_s3_client
    object_key = "covers/#{novel_id}.png"
    @s3_client.delete_object(bucket: @bucket_name, key: object_key)
  rescue => e
    Rails.logger.error "Failed to delete cover from S3: #{e.message}"
  end
end