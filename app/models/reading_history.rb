class ReadingHistory < ApplicationRecord
  belongs_to(:user)
  belongs_to(:novel)
    belongs_to(:chapter, foreign_key: :chapter_no, primary_key: :chapter_no, optional: true)

  validates(:user_id, uniqueness: { scope: :novel_id, message: "มีประวัติเรื่องนี้อยู่แล้ว" })
end
