class AddNovelIdAndChapterNoToUnlockedChapters < ActiveRecord::Migration[8.1]
  def change
    add_column :unlocked_chapters, :novel_id, :integer
    add_column :unlocked_chapters, :chapter_no, :integer
    add_index :unlocked_chapters, [:user_id, :novel_id, :chapter_no], unique: true
  end
end
