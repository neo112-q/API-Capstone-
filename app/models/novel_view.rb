class NovelView < ApplicationRecord
  belongs_to(:novel)
  belongs_to(:user, optional: true)
  
  validates(:novel_id, presence: true)
  validates(:session_id, presence: true, if: -> { user_id.nil?() })
  
  scope(:today, -> { where(viewed_at: Time.current.beginning_of_day..Time.current) })
  scope(:this_week, -> { where(viewed_at: 1.week.ago..Time.current) })
end