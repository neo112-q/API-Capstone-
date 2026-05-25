class AddCoverPathToNovels < ActiveRecord::Migration[8.1]
  def change
    add_column :novels, :cover_path, :string unless column_exists?(:novels, :cover_path)
  end
end
