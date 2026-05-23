# db/migrate/xxxx_create_comments.rb
class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.text :content, null: false
      t.references :user, null: false, foreign_key: true
      t.references :novel, null: false, foreign_key: true
      t.integer :chapter_no, null: false
      t.timestamps
    end
    
    # ✅ เพิ่ม index เพื่อค้นหาเร็วยิ่งขึ้น
    add_index :comments, [:novel_id, :chapter_no, :created_at], name: 'idx_comments_on_chapter'
  end
end