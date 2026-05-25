class AddStripeConnectToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :earnings_balance, :integer, default: 0
    add_column :users, :stripe_account_id, :string
    add_column :users, :stripe_charges_enabled, :boolean, default: false
  end
end
