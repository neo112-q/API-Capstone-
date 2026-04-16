class CreateEngagements < ActiveRecord::Migration[8.1]
  def change
    create_table :likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :likeable, polymorphic: true, null: false # เก็บได้ทั้ง Novel และ Chapter
      t.timestamps
    end

    create_table :follows do |t|
      t.references :user, null: false, foreign_key: true
      t.references :novel, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :likes, [:user_id, :likeable_id, :likeable_type], unique: true
    add_index :follows, [:user_id, :novel_id], unique: true
  end
end