class AddStripeAccountIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :stripe_account_id, :string
  end
end
