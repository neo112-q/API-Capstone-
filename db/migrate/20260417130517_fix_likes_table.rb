# db/migrate/xxxx_fix_likes_table.rb
class FixLikesTable < ActiveRecord::Migration[8.1]
  def change
    # ลบตารางเดิม
    drop_table :likes if table_exists?(:likes)
    
    # สร้างใหม่
    create_table :likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :likeable, polymorphic: true, null: false
      t.timestamps
    end
    
    add_index :likes, [:user_id, :likeable_id, :likeable_type], unique: true
  end
end