class CreateChapters < ActiveRecord::Migration[8.1]
  def change
    # คู่กันเป็น PK
    create_table(:chapters, primary_key: [:novel_id, :chapter_no ]) do |t|
      t.integer(:novel_id, null: false)
      t.integer(:chapter_no, null: false)
      t.string(:title, null: false)
      t.timestamps()
    end
        add_foreign_key(:chapters, :novels)
  end
end
