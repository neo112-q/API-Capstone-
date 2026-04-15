class Chapter < ApplicationRecord
  self.primary_key = [:novel_id, :chapter_no]
  belongs_to(:novel)

  validates(:chapter_no, presence: true, numericality: { only_integer: true, greater_than: 0 })
  validates(:title, presence: true)

  # เช็คลำดับก่อนสร้างได้ด้วย
  validate(:must_be_sequential, on: :create)

  has_many(:unlocked_chapters, dependent: :destroy)

  private

  def must_be_sequential()
    # นับว่าตอนนี้นิยายเรื่องนี้มีกี่ตอนแล้วนะ
    last_no = novel.chapters.count()
    # ถ้าจะสร้างตอนใหม่ เลขตอนต้องเท่ากับ (จำนวนตอนเดิม + 1) เท่านั้น เพื่อจะได้ไม่มีปัญหานะ
    if chapter_no != last_no + 1
      errors.add(:chapter_no, "ต้องเป็นตอนที่ #{last_no + 1} เท่านั้น (ห้ามข้ามตอน)")
    end
  end
end