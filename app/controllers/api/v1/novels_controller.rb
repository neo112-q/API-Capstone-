class Api::V1::NovelsController < ::ApplicationController
  # GET /api/v1/novels
  def index()
    novels = Novel.all().order(updated_at: :desc)
    render(json: novels, status: :ok)
  end

  # GET /api/v1/novels/:id
  def show()
    novel = Novel.find(params[:id])
    render(json: novel, status: :ok)
  end

  # POST /api/v1/novels
  def create()
    novel = Novel.new(novel_params())
    if novel.save()
      render(json: novel, status: :created)
    else
      render(json: { errors: novel.errors.full_messages }, status: :unprocessable_entity)
    end
  end

  # PATCH/PUT /api/v1/novels/:id
  def update()
    novel = Novel.find(params[:id])
    if novel.update(novel_params())
      render(json: novel, status: :ok)
    else
      render(json: { errors: novel.errors.full_messages }, status: :unprocessable_entity)
    end
  end

  # DELETE /api/v1/novels/:id
  def destroy()
    novel = Novel.find(params[:id])
    novel.destroy()
    render(json: { message: "Novel deleted successfully" }, status: :ok)
  end

  private

  def novel_params()
    # รับแค่ metadata ไม่ลึก ๆ นะ เพื่อความปลอดภัย
    params.require(:novel).permit(:title, :pen_name, :status, :user_id)
  end
end