class Api::V1::LikesController < ::ApplicationController
  before_action(:authorize_request)

  def toggle()
    if params[:id] && params[:novel_id]
      chapter = Chapter.find_by(
        novel_id: params[:novel_id],
        chapter_no: params[:id]
      )
      
      if chapter.nil?
        return render(json: { error: "ไม่พบตอนที่ต้องการ" }, status: :not_found)
      end
      
      like = ChapterLike.find_by(
        user_id: @current_user.id,
        novel_id: chapter.novel_id,
        chapter_no: chapter.chapter_no
      )
      
      if like
        like.destroy
        # ✅ สั่ง reload ค่า likes_count จาก DB จริงๆ
        like_count = ChapterLike.where(novel_id: chapter.novel_id, chapter_no: chapter.chapter_no).count
        render json: {
          liked: false,
          like_count: like_count
        }, status: :ok
      else
        ChapterLike.create!(
          user_id: @current_user.id,
          novel_id: chapter.novel_id,
          chapter_no: chapter.chapter_no
        )
        # ✅ สั่ง reload ค่า likes_count จาก DB จริงๆ
        like_count = ChapterLike.where(novel_id: chapter.novel_id, chapter_no: chapter.chapter_no).count
        render json: {
          liked: true,
          like_count: like_count
        }, status: :created
      end
    end
  end
end