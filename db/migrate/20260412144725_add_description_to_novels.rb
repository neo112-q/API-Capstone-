class AddDescriptionToNovels < ActiveRecord::Migration[8.1]
  def change
    add_column :novels, :description, :text
  end
end
