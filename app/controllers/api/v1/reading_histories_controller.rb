class Api::V1::ReadingHistoriesController < ::ApplicationController
  before_action :authorize_request

  def index
    histories = @current_user.reading_histories.includes(:novel).order(updated_at: :desc)
    
    result = histories.map do |h|
      {
        novel_id: h.novel_id,
        novel_title: h.novel.title,      
        pen_name: h.novel.pen_name,   
        cover_path: h.novel.cover_path,  
        chapter_no: h.chapter_no,
        last_read_at: h.updated_at,
        genres: h.novel.genres.as_json(only: [:id, :name]),
        tags: h.novel.tags || []
      }
    end
    
    render json: { reading_histories: result }, status: :ok
  end

  def create
    novel = Novel.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:chapter_no])

    history = @current_user.reading_histories.find_or_initialize_by(novel: novel)
    history.chapter_no = chapter.chapter_no

    if history.save
      render json: { message: "บันทึกประวัติการอ่านเรียบร้อย", last_read: history.chapter_no }, status: :ok
    else
      render json: { errors: history.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    history = @current_user.reading_histories.find_by!(novel_id: params[:id])
    history.destroy
    render json: { message: "ลบประวัติการอ่านเรื่องนี้แล้ว" }, status: :ok
  end
end