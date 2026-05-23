class Api::V1::Admin::UsersController < ApplicationController
  before_action :authorize_request
  before_action :authorize_admin

  def index
    users = User.order(created_at: :desc)
    
    render(json: {
      total: users.count,
      users: users.map do |user|
        {
          id: user.id,
          email: user.email,
          username: user.username,
          role: user.role,
          status: user.status,
          coin_balance: user.coin_balance,
          created_at: user.created_at,
          avatar_path: user.avatar_path
        }
      end
    }, status: :ok)
  end

  # app/controllers/api/v1/admin/users_controller.rb

    def update
        user = User.find(params[:id])
        
        # ป้องกันการแก้ไขตัวเอง (ห้ามแบนตัวเอง)
        if user.id == @current_user.id
            return render(json: { error: "คุณไม่สามารถแก้ไขสถานะตัวเองได้" }, status: :bad_request)
        end
        
        # รับเฉพาะ status (แบน/ปลดแบน) เท่านั้น ห้ามยุ่งกับ role
        if params[:status].present?
            user.status = params[:status]
        end

        # ลบ Logic การอัปเดต role ทิ้งไปเลย เพื่อล็อคระบบ
        
        if user.save
            render(json: { 
            message: "อัปเดตสถานะผู้ใช้ #{user.username} สำเร็จ", 
            user: {
                id: user.id,
                username: user.username,
                role: user.role, # role จะยังคงเป็นค่าเดิมเสมอ
                status: user.status
            }
            }, status: :ok)
        else
            render(json: { errors: user.errors.full_messages }, status: :unprocessable_entity)
        end
    end

  def destroy
    user = User.find(params[:id])
    
    if user.id == @current_user.id
      return render(json: { error: "คุณไม่สามารถลบตัวเองได้" }, status: :bad_request)
    end

    # ✅ ลบข้อมูลที่เกี่ยวข้อง
    ActiveRecord::Base.transaction do
      # ลบ chapters ใน S3
      user.novels.each do |novel|
        novel.chapters.each do |chapter|
          delete_chapter_from_s3(novel.user_id, novel.id, chapter.chapter_no)
        end
        delete_cover_from_s3(novel.id)
      end
      
      user.destroy!
    end
    
    render(json: { message: "ลบผู้ใช้ #{user.email} พร้อมข้อมูลทั้งหมดเรียบร้อย" }, status: :ok)
  rescue => e
    render(json: { error: e.message }, status: :internal_server_error)
  end

  private

  def set_s3_client
    @s3_client = Aws::S3::Client.new(
      endpoint: ENV.fetch('MINIO_ENDPOINT', 'http://localhost:9000'),
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