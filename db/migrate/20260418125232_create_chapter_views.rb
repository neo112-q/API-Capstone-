class CreateChapterViews < ActiveRecord::Migration[8.1]
  def change
    create_table :chapter_views do |t|
      t.integer :novel_id, null: false
      t.integer :chapter_no, null: false
      t.references :user, foreign_key: true
      t.string :session_id
      t.datetime :viewed_at, null: false
      t.timestamps
    end
    
    # ✅ ใช้ foreign key แบบ composite (อ้างอิง chapters ที่ใช้ composite key)
    add_foreign_key :chapter_views, :chapters, column: [:novel_id, :chapter_no], primary_key: [:novel_id, :chapter_no]
    
    add_index :chapter_views, [:novel_id, :chapter_no], name: 'idx_chapter_views_on_chapter'
    add_index :chapter_views, [:novel_id, :chapter_no, :user_id], name: 'idx_chapter_views_on_user', unique: true, where: "user_id IS NOT NULL"
    add_index :chapter_views, [:novel_id, :chapter_no, :session_id], name: 'idx_chapter_views_on_session', unique: true, where: "session_id IS NOT NULL"
    add_index :chapter_views, [:novel_id, :chapter_no, :viewed_at], name: 'idx_chapter_views_on_date'
  end
end