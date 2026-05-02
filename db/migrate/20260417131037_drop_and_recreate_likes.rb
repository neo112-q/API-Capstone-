class DropAndRecreateLikes < ActiveRecord::Migration[8.1]
  def up
    drop_table :likes if table_exists?(:likes)
    
    create_table :likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :likeable, polymorphic: true, null: false
      t.timestamps
    end
    
    add_index :likes, [:user_id, :likeable_id, :likeable_type], unique: true, name: 'index_likes_on_user_and_likeable'
  end

  def down
    drop_table :likes
  end
end