# app/models/novel.rb
class Novel < ApplicationRecord
  belongs_to(:user)
  
  # ✅ แก้ไข: ระบุ foreign_key และ primary_key ให้ชัดเจน
  has_many(:chapters, 
           foreign_key: :novel_id, 
           primary_key: :id, 
           dependent: :destroy)
  
  has_many(:novel_genres, dependent: :destroy)
  has_many(:genres, through: :novel_genres)
  has_many(:follows, dependent: :destroy)
  has_many(:followers, through: :follows, source: :user)
  has_many(:likes, as: :likeable, dependent: :destroy)
  has_many(:purchases, dependent: :destroy)
  
  # ✅ เพิ่มความสัมพันธ์โดยตรงเพื่อให้ลบได้
  has_many(:unlocked_chapters, 
           foreign_key: :novel_id, 
           primary_key: :id, 
           dependent: :delete_all)
  
  has_many(:chapter_likes, 
           foreign_key: :novel_id, 
           primary_key: :id, 
           dependent: :delete_all)
  
  has_many(:chapter_views, 
           foreign_key: :novel_id, 
           primary_key: :id, 
           dependent: :delete_all)
  
  has_many(:reading_histories, dependent: :delete_all)

  validates(:title, presence: true)
  validates(:pen_name, presence: true)
  validate(:readonly_user_id, on: :update)
  
  enum(:status, { draft: 0, published: 1, writing: 2 })

  def total_views()
    ChapterView.where(novel_id: id).count()
  end
  
  def today_views()
    chapters.joins(:chapter_views)
            .where(chapter_views: { viewed_at: Time.current.beginning_of_day..Time.current })
            .count()
  end
  
  def unique_views()
    user_count = ChapterView.where(novel_id: id).where.not(user_id: nil).distinct.count(:user_id)
    session_count = ChapterView.where(novel_id: id).where(user_id: nil).distinct.count(:session_id)
    user_count + session_count
  end

  private

  def readonly_user_id()
    errors.add(:user_id, "is immutable") if user_id_changed?()
  end
end