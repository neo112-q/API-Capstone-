class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references(:user, null: false, foreign_key: false)
      t.references(:chapter, null: false, foreign_key: false)
      t.text(:content)

      t.timestamps()
    end
  end
end
