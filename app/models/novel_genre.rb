class NovelGenre < ApplicationRecord
  belongs_to :novel
  belongs_to :genre
end