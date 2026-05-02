class ReadingHistory < ApplicationRecord
  belongs_to :user
  belongs_to :novel
  
  # ไม่ต้องมี belongs_to :chapter เพราะใช้แค่ chapter_no
  
  validates :user_id, uniqueness: { scope: :novel_id, message: "มีประวัติเรื่องนี้อยู่แล้ว" }
  validates :chapter_no, presence: true
end