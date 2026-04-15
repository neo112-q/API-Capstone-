class AddMonetizationToSystem < ActiveRecord::Migration[8.1]
  def change()
    # User เก็บเหรียญ และ ID Stripe
    add_column(:users, :coin_balance, :integer, default: 0)
    add_column(:users, :stripe_customer_id, :string)
    
    # Novel สิทธิ์ในการติดเหรียญ
    add_column(:novels, :is_premium, :boolean, default: false)
    
    # Chapter ราคาต่อตอน
    add_column(:chapters, :price, :integer, default: 0)
    
    end
end