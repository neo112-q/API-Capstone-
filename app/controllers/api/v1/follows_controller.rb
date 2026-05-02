class Api::V1::FollowsController < ::ApplicationController
  before_action(:authorize_request)

  # C กดติดตาม
  def create()
    novel = Novel.find(params[:id]) 
    follow = @current_user.follows.find_or_create_by(novel: novel)
    render(json: { message: "ติดตามแล้ว", follow: true, follow_count: novel.follows.count }, status: :created)
  end

  # R ดูนิยายที่ติดตามทั้งหมด
  def index()
    render(json: { followed_novels: @current_user.followed_novels }, status: :ok)
  end

  # D เลิกติดตาม
  def destroy()
    novel = Novel.find(params[:id]) 
    follow = @current_user.follows.find_by(novel_id: params[:id]) 
    follow.destroy()
    render(json: { message: "เลิกติดตามแล้ว", followed: false, follow_count: novel.follows.count }, status: :ok)
  end
end