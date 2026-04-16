class Api::V1::LikesController < ::ApplicationController
  before_action(:authorize_request)

  def toggle()
    if params[:novel_id]
      @likeable = Novel.find(params[:novel_id])
    elsif params[:chapter_id]
      @likeable = Chapter.find(params[:chapter_id])
    else
      return render(json: { error: "ข้อมูลไม่ถูกต้อง" }, status: :bad_request)
    end

    like = @current_user.likes.find_by(likeable: @likeable)

    if like
      like.destroy()
      render(json: { message: "เลิกถูกใจแล้ว", liked: false }, status: :ok)
    else
      @current_user.likes.create!(likeable: @likeable)
      render(json: { message: "ถูกใจแล้ว", liked: true }, status: :created)
    end
  end
end