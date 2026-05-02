class Novel < ApplicationRecord
  # เชื่อมแบบ FK
  belongs_to(:user)
  has_many(:chapters, dependent: :destroy) # นิยาย 1 เรื่องมีหลายตอน
  has_many(:novel_genres, dependent: :destroy)
  has_many(:genres, through: :novel_genres)
  has_many(:follows, dependent: :destroy)
  has_many(:followers, through: :follows, source: :user)
  has_many(:likes, as: :likeable, dependent: :destroy)
  has_many(:purchases, dependent: :destroy)
  
  # ❌ ลบบรรทัดนี้ (ไม่มี novel_views แล้ว)
  # has_many(:novel_views, dependent: :destroy)
  
  # กรอกข้อมูลแบบนี้เท่านั้นนะจ๊ะ
  validates(:title, presence: true)
  validates(:pen_name, presence: true)
  # ล็อคไม่ให้เปลี่ยนเจ้าของนิยายตอนอัปเดตตามนั้น
  validate(:readonly_user_id, on: :update)
  
  enum(:status, { draft: 0, published: 1, writing: 2 })

  # ✅ แก้ method ใหม่ ให้ใช้ chapter_views แทน
  # ✅ ถูกต้อง - นับทุก chapter ที่ถูกอ่าน (รวมซ้ำก็ไม่นับเพิ่ม)
  def total_views()
    ChapterView.where(novel_id: id).count()
  end
  
  # ✅ ถ้าอยากได้ยอดวิววันนี้
  def today_views()
    chapters.joins(:chapter_views)
            .where(chapter_views: { viewed_at: Time.current.beginning_of_day..Time.current })
            .count()
  end
  
  # ✅ unique views
  def unique_views()
    # นับ unique user + unique session จากทุก chapter
    user_count = ChapterView.where(novel_id: id).where.not(user_id: nil).distinct.count(:user_id)
    session_count = ChapterView.where(novel_id: id).where(user_id: nil).distinct.count(:session_id)
    user_count + session_count
  end

  private

  def readonly_user_id()
    errors.add(:user_id, "is immutable") if user_id_changed?()
  end
end