class AddFreeDateToChapters < ActiveRecord::Migration[8.1]
  def change
    add_column :chapters, :free_date, :datetime
  end
end