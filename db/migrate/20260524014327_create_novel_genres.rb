class CreateNovelGenres < ActiveRecord::Migration[8.1]
  def change
    create_table :novel_genres do |t|
      t.references :novel, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true
      t.timestamps
    end
    add_index :novel_genres, [:novel_id, :genre_id], unique: true
  end
end
