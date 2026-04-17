class Api::V1::ReadingHistoriesController < ::ApplicationController
  before_action(:authorize_request)

  # R ดูประวัติการอ่านทั้งหมดของตัวเอง
  def index
    histories = @current_user.reading_histories.includes(:novel).order(updated_at: :desc)

    result = histories.map do |h|
      chapter = h.novel.chapters.find_by(chapter_no: h.chapter_no)
      {
        novel_id: h.novel.id,
        novel_title: h.novel.title,
        chapter_no: h.chapter_no,
        chapter_title: chapter&.title || "ไม่พบชื่อตอน",
        last_read_at: h.updated_at
      }
    end

    render(json: { reading_histories: result }, status: :ok)
  end

  # C & U บันทึกหรืออัปเดตประวัติการอ่าน
  def create
    novel = Novel.find(params[:novel_id])
    chapter = novel.chapters.find_by!(chapter_no: params[:chapter_no])

    # ค้นหาว่ามีประวัติเรื่องนี้ไหม ถ้าไม่มีก็ให้เตรียมสร้างใหม่
    history = @current_user.reading_histories.find_or_initialize_by(novel: novel)

    # อัปเดตว่าเป็นตอนล่าสุดที่อ่านแล้วนะ
    history.chapter = chapter

    if history.save()
      render(json: {
        message: "บันทึกประวัติการอ่านเรียบร้อย",
        last_read: history.chapter.chapter_no
      }, status: :ok)
    else
      render(json: { errors: history.errors.full_messages }, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "หานิยายหรือตอนไม่เจอ" }, status: :not_found)
  end

  # D ลบประวัติการอ่าน เผื่อคนอ่านอยากล้างประวัติ
  def destroy
    history = @current_user.reading_histories.find_by!(novel_id: params[:id])
    history.destroy()

    render(json: { message: "ลบประวัติการอ่านเรื่องนี้แล้ว" }, status: :ok)
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "ไม่พบประวัติการอ่าน" }, status: :not_found)
  end
end
