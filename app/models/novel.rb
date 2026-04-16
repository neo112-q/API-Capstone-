class Novel < ApplicationRecord
  # เชื่อมแบบ FK
  belongs_to(:user)
  has_many(:chapters, dependent: :destroy) # นิยาย 1 เรื่องมีหลายตอน
  has_many :novel_genres, dependent: :destroy
  has_many :genres, through: :novel_genres
  # กรอกข้อมูลแบบนี้เท่านั้นนะจ๊ะ
  validates(:title, presence: true)
  validates(:pen_name, presence: true)
  # ล็อคไม่ให้เปลี่ยนเจ้าของนิยายตอนอัปเดตตามนั้น
  validate(:readonly_user_id, on: :update)
  
  has_many(:follows, dependent: :destroy)
  has_many(:followers, through: :follows, source: :user)
  enum(:status, { draft: 0, published: 1, writing: 2 })

  has_many(:likes, as: :likeable, dependent: :destroy)
  has_many(:purchases, dependent: :destroy)

  private

  def readonly_user_id()
    errors.add(:user_id, "is immutable") if user_id_changed?()
  end
end