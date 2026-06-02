class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :username
      t.string :password_digest
      t.string :pen_name
      t.text :bio
      t.string :avatar_path

      t.timestamps
    end
  end
end