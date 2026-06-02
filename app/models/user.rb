class User < ApplicationRecord
  has_secure_password() 
  has_many(:novels, dependent: :destroy)
  has_one_attached(:avatar)
  validates(:email, presence: true, uniqueness: true)
  validates(:username, presence: true, uniqueness: true)

  has_many(:follows, dependent: :destroy)
  has_many(:followed_novels, through: :follows, source: :novel)
  has_many(:unlocked_chapters, dependent: :destroy)
  has_many(:likes, dependent: :destroy)
  has_many(:purchases, dependent: :destroy)
  has_many(:payouts, dependent: :destroy)
  has_many(:reading_histories, dependent: :destroy)
  has_many(:comments, dependent: :destroy)
  enum :role, { user: "user", admin: "admin" }, default: "user"
  enum :status, { active: "active", banned: "banned" }, default: "active"
  
  def generate_password_reset_token
    self.reset_password_token = rand(100000..999999).to_s
    self.reset_password_sent_at = Time.current
    save!(validate: false)
  end

  def password_reset_valid?
    (self.reset_password_sent_at + 15.minutes) > Time.current
  end

  def admin?
    role == "admin"
  end
  
  def banned?
    status == "banned"
  end
end
