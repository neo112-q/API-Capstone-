class CreatePurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.references :novel, null: false, foreign_key: true
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :platform_fee, precision: 10, scale: 2, null: false # 40%
      t.decimal :author_revenue, precision: 10, scale: 2, null: false # 60%
      t.timestamps
    end
  end
end