class CreateChapterLikes < ActiveRecord::Migration[8.1]
  def change
    create_table :chapter_likes do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :novel_id, null: false
      t.integer :chapter_no, null: false
      t.timestamps
    end
    
    add_index :chapter_likes, [:user_id, :novel_id, :chapter_no], unique: true
  end
end