class User < ApplicationRecord
  has_secure_password() 
  has_many(:novels, dependent: :destroy)
  has_one_attached(:avatar)
  validates(:email, presence: true, uniqueness: true)
  validates(:username, presence: true, uniqueness: true)
end