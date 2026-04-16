class AddStatusAndViewsToNovels < ActiveRecord::Migration[8.1]
  def change
    add_column :novels, :status, :integer, default: 0
    add_column :novels, :view_count, :integer, default: 0
    add_column :chapters, :view_count, :integer, default: 0
  end
end