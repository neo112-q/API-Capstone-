class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :pen_name, :string
    add_column :users, :bio, :text
    add_column :users, :avatar_path, :string
  end
end
