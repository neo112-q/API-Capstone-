class NovelTfidfVector < ApplicationRecord
  belongs_to :novel

  has_neighbors :tf_idf
end