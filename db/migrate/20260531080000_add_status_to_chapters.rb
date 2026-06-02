class AddStatusToChapters < ActiveRecord::Migration[8.1]
  def up
    add_column :chapters, :status, :string, default: 'draft'
    add_index :chapters, :status
    # Backfill existing chapters — they were created before this migration, treat as draft
    Chapter.where(status: nil).update_all(status: 'draft')
    change_column_null :chapters, :status, false
  end

  def down
    remove_column :chapters, :status
  end
end
