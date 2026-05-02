# app/models/chapter.rb
class Chapter < ApplicationRecord
  self.primary_key = [:novel_id, :chapter_no]
  belongs_to(:novel)

  validates(:chapter_no, presence: true, numericality: { only_integer: true, greater_than: 0 })
  validates(:title, presence: true)

  validate(:must_be_sequential, on: :create)

  # ✅ แก้ไข: ใช้ delete_all แทน destroy เพื่อ bypass composite key issues
  has_many(:unlocked_chapters, dependent: :delete_all, foreign_key: :novel_id)
  has_many(:chapter_likes, dependent: :delete_all, foreign_key: :novel_id)
  has_many(:chapter_views, dependent: :delete_all, foreign_key: :novel_id)
  
  has_many(:likes, as: :likeable, dependent: :destroy)
  
  def chapter_likes
    ChapterLike.where(novel_id: novel_id, chapter_no: chapter_no)
  end
  
  def is_liked_by?(user)
    return false unless user

    ChapterLike.exists?(
      user_id: user.id,
      novel_id: self.novel_id,
      chapter_no: self.chapter_no
    )
  end

  def likes_count
    ChapterLike.where(novel_id: novel_id, chapter_no: chapter_no).count
  end
  
  def view_count
    ChapterView.where(novel_id: novel_id, chapter_no: chapter_no).count
  end
  
  def reload_likes_count!
    @likes_count = nil
    likes_count
  end
  
  private

  def must_be_sequential
    last_no = novel.chapters.count
    if chapter_no != last_no + 1
      errors.add(:chapter_no, "ต้องเป็นตอนที่ #{last_no + 1} เท่านั้น (ห้ามข้ามตอน)")
    end
  end
end