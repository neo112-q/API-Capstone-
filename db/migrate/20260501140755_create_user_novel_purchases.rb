class CreateUserNovelPurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :user_novel_purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.references :novel, null: false, foreign_key: true
      t.integer :price_paid, null: false
      t.datetime :purchased_at, null: false
      t.timestamps
    end
    
    add_index :user_novel_purchases, [:user_id, :novel_id], unique: true
  end
end
