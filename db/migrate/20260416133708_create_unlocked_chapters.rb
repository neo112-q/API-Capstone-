class CreateUnlockedChapters < ActiveRecord::Migration[8.1]
  def change
    create_table :unlocked_chapters do |t|
      t.references :user, null: false, foreign_key: true
      t.references :chapter, null: false 
      t.decimal :price_paid, precision: 10, scale: 2, default: 0.0 

      t.timestamps
    end
    
    add_index :unlocked_chapters, [:user_id, :chapter_id], unique: true
  end
end