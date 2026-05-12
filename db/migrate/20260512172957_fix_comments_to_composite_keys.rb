class FixCommentsToCompositeKeys < ActiveRecord::Migration[8.1]
  def change
    remove_column(:comments, :chapter_id, :bigint)

    add_column(:comments, :novel_id, :integer, null: false)
    add_column(:comments, :chapter_no, :integer, null: false)

    add_index(:comments, [:novel_id, :chapter_no])
  end
end