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
    followed_novels = @current_user.followed_novels
    
    result = followed_novels.map do |novel|
      {
        id: novel.id,
        title: novel.title,
        pen_name: novel.pen_name,
        description: novel.description,
        cover_path: novel.cover_path,
        status: novel.status,
        genres: novel.genres.as_json(only: [:id, :name]),
        tags: novel.tags || []   # ✅ เพิ่ม tags
      }
    end
    
    render(json: { followed_novels: result }, status: :ok)
  end

  # D เลิกติดตาม
  def destroy()
    novel = Novel.find(params[:id]) 
    follow = @current_user.follows.find_by(novel_id: params[:id]) 
    follow.destroy()
    render(json: { message: "เลิกติดตามแล้ว", followed: false, follow_count: novel.follows.count }, status: :ok)
  end
end