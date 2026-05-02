class ChapterView < ApplicationRecord
  # ไม่ต้องมี belongs_to(:chapter) เพราะไม่มี foreign key ปกติ
  # แต่ให้สร้าง method ช่วยแทน
  
  validates(:novel_id, presence: true)
  validates(:chapter_no, presence: true)
  validates(:viewed_at, presence: true)
  
  # helper method หา chapter
  def chapter()
    Chapter.find_by(novel_id: novel_id, chapter_no: chapter_no)
  end
end