class AddCompositeKeysToComments < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:comments, :novel_id)
      add_column(:comments, :novel_id, :integer, null: false)
    end

    unless column_exists?(:comments, :chapter_no)
      add_column(:comments, :chapter_no, :integer, null: false)
    end

    unless index_exists?(:comments, [:novel_id, :chapter_no])
      add_index(:comments, [:novel_id, :chapter_no])
    end
  end
end