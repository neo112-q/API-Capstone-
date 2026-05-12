class Comment < ApplicationRecord
  belongs_to(:user)
  belongs_to(:chapter, foreign_key: [:novel_id, :chapter_no], optional: true)
  validates(:content, presence: true)
end