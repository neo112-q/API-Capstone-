class UnlockedChapter < ApplicationRecord
  belongs_to :user
  belongs_to :novel  
  validates :user_id, uniqueness: { scope: [:novel_id, :chapter_no] }
end