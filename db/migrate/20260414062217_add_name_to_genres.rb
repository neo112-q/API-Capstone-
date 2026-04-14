class AddNameToGenres < ActiveRecord::Migration[8.1]
  def change
    add_column :genres, :name, :string
  end
end
