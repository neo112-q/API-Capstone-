class CreateNovels < ActiveRecord::Migration[8.1]
  def change
    create_table :novels do |t|
      t.string :title
      t.string :pen_name
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
