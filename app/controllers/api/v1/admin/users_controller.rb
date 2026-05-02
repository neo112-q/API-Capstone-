class Api::V1::Admin::UsersController < ApplicationController
  # บังคับล็อกอิน และ บังคับว่าเป็น Admin
  before_action :authorize_request
  before_action :authorize_admin

  # R ดูผู้ใช้งานทั้งหมด เรียงจากสมัครล่าสุด
  def index
    users = User.order(created_at: :desc)
    
    render(json: {
      total_users: users.count,
      users: users.as_json(only: [:id, :email, :username, :role, :status, :coin_balance, :created_at])
    }, status: :ok)
  end

  # U แบน  ปลดแบน
  def update
    user = User.find(params[:id])
    
    if user.update(user_params)
      render(json: { 
        message: "อัปเดตสถานะผู้ใช้ #{user.username} สำเร็จ", 
        user: user.as_json(only: [:id, :username, :status]) 
      }, status: :ok)
    else
      render(json: { errors: user.errors.full_messages }, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "ไม่พบผู้ใช้งานนี้" }, status: :not_found)
  end

  # D ลบผู้ใช้และขยะทั้งหมดทิ้ง
  def destroy
    user = User.find(params[:id])
    
    if user.id == @current_user.id
      return render(json: { error: "คุณไม่สามารถลบตัวเองได้นะจ๊ะ จุ๊บ ๆ " }, status: :bad_request)
    end

    user.destroy
    render(json: { message: "ลบผู้ใช้ #{user.email} พร้อมข้อมูลที่เกี่ยวข้องทั้งหมดแล้ว" }, status: :ok)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "ไม่พบผู้ใช้งานนี้" }, status: :not_found)
  end

  private

  def user_params
    # อนุญาตให้แอดมินแก้ได้แค่ status
    params.permit(:status)
  end
end