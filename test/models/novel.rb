class Novel < ApplicationRecord
  belongs_to :user

  has_many :novel_genres, dependent: :destroy
  has_many :genres, through: :novel_genres
end