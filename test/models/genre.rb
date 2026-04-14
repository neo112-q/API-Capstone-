class Genre < ApplicationRecord
  has_many :novel_genres
  has_many :novels, through: :novel_genres
end