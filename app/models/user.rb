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
  has_many(:reading_histories, dependent: :destroy)

  enum :role, { user: "user", admin: "admin" }
  enum :status, { active: "active", banned: "banned" } 
  validates( :email, presence: true, uniqueness: true)
  validates(:username, presence: true, uniqueness: true) 
end
