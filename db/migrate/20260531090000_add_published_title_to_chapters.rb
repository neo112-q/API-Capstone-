class AddPublishedTitleToChapters < ActiveRecord::Migration[8.1]
  def change
    add_column :chapters, :published_title, :string
  end
end
