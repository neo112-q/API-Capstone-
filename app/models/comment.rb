# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :novel
  belongs_to :chapter, foreign_key: [:novel_id, :chapter_no], optional: true
  
  validates :content, presence: true, length: { maximum: 1000 }
  validates :novel_id, presence: true
  validates :chapter_no, presence: true
  
  default_scope -> { order(created_at: :desc) }
end