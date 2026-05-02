class CreateNovelViews < ActiveRecord::Migration[8.1]
  def change
    create_table :novel_views do |t|
      t.references :novel, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :session_id
      t.datetime :viewed_at, null: false
      t.timestamps
    end
    
    # indexes สำหรับ query เร็ว
    add_index :novel_views, [:novel_id, :user_id], name: 'idx_novel_views_on_user'
    add_index :novel_views, [:novel_id, :session_id], name: 'idx_novel_views_on_session'
    add_index :novel_views, [:novel_id, :viewed_at], name: 'idx_novel_views_on_date'
  end
end