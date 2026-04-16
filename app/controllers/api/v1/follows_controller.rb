class Api::V1::FollowsController < ::ApplicationController
  before_action(:authorize_request)

  # C กดติดตาม
  def create()
    novel = Novel.find(params[:id]) 
    follow = @current_user.follows.find_or_create_by(novel: novel)
    render(json: { message: "ติดตามแล้ว", follow: follow }, status: :created)
  end

  # R ดูนิยายที่ติดตามทั้งหมด
  def index()
    render(json: { followed_novels: @current_user.followed_novels }, status: :ok)
  end

  # D เลิกติดตาม
  def destroy()
    follow = @current_user.follows.find_by!(novel_id: params[:id]) 
    follow.destroy()
    render(json: { message: "เลิกติดตามแล้ว" }, status: :ok)
  end
end