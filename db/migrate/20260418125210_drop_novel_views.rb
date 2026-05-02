class DropNovelViews < ActiveRecord::Migration[8.1]
  def change
    drop_table :novel_views if table_exists?(:novel_views)
  end
end