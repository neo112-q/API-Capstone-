class CreatePayouts < ActiveRecord::Migration[8.1]
  def change
    create_table :payouts do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount_coins, null: false
      t.decimal :amount_usd, precision: 10, scale: 2, null: false
      t.string :stripe_transfer_id
      t.string :status, default: 'pending', null: false
      t.text :error_message

      t.timestamps
    end

    add_index :payouts, :status
  end
end
