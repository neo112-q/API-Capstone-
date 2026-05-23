class AddTagsToNovels < ActiveRecord::Migration[8.1]
  def change
    add_column :novels, :tags, :string, array: true, default: []
  end
end