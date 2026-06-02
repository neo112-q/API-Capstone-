# db/migrate/xxx_add_role_and_status_to_users.rb
class AddRoleAndStatusToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, default: "user", null: false
    add_column :users, :status, :string, default: "active", null: false
    add_index :users, :role
    add_index :users, :status
  end
end