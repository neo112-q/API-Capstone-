class Api::V1::NovelsController < ::ApplicationController
  # เรียก Token เฉพาะตอน C, U, D
  before_action(:authorize_request, only: [:create, :update, :destroy])

  # ดูได้ทุกคนนะ
  def index()
    render(json: Novel.all().order(updated_at: :desc))
  end

  # สร้างนิยาย ดึง user_id จาก Token อัตโนมัติ
  def create()
    novel = @current_user.novels.build(
      title: params[:novel][:title],
      description: params[:novel][:description],
      pen_name: @current_user.pen_name
    )
    
    if novel.save()
      render(json: novel, status: :created)
    else
      render(json: { errors: novel.errors.full_messages }, status: :unprocessable_entity)
    end
  end

  # แก้ไขข้อมูล แก้ได้เฉพาะนิยายของตัวเองเท่านั้นนะ
  def update()
    novel = @current_user.novels.find(params[:id])
    
    if novel.update(
      title: params[:novel][:title],
      description: params[:novel][:description],
      pen_name: @current_user.pen_name
    )
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
      description: novel.description
    }, status: :ok)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "ไม่พบนิยาย" }, status: :not_found)
  end

  # ลบได้เฉพาะนิยายของตัวเองเท่านั้น
  def destroy()
    novel = @current_user.novels.find(params[:id])
    novel.destroy()
    render(json: { message: "Your novel has been deleted" }, status: :ok)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "You don't have permission to delete this novel" }, status: :forbidden)
  end
  private

  def novel_params()
    # รับแค่ metadata ไม่ลึก ๆ นะ เพื่อความปลอดภัย
    params.require(:novel).permit(:title, :description)
  end
end