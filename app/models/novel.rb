class Novel < ApplicationRecord
  # เชื่อมแบบ FK
  belongs_to(:user)
  has_many(:chapters, dependent: :destroy) # นิยาย 1 เรื่องมีหลายตอน
  # กรอกข้อมูลแบบนี้เท่านั้นนะจ๊ะ
  validates(:title, presence: true)

  # ล็อคไม่ให้เปลี่ยนเจ้าของนิยายตอนอัปเดตตามนั้น
  validate(:readonly_user_id, on: :update)

  private

  def readonly_user_id()
    errors.add(:user_id, "is immutable") if user_id_changed?()
  end
end