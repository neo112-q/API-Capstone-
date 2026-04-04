class Novel < ApplicationRecord
  # เชื่อมแบบ FK
  belongs_to(:user)

  # กรอกข้อมูลแบบนี้เท่านั้นนะจ๊ะ
  validates(:title, presence: true)
  validates(:status, inclusion: { in: %w(ongoing finished) })

  # ล็อคไม่ให้เปลี่ยนเจ้าของนิยายตอนอัปเดตตามนั้น
  validate(:readonly_user_id, on: :update)

  private

  def readonly_user_id()
    if user_id_changed?()
      errors.add(:user_id, "cannot be changed once created")
    end
  end
end
