class CreateReadingHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :reading_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :novel, null: false, foreign_key: true
      t.integer :chapter_no, null: false

      t.timestamps
    end

    add_index :reading_histories, [ :user_id, :novel_id ], unique: true
  end
end
