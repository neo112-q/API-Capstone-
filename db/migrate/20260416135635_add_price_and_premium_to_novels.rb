class AddPriceAndPremiumToNovels < ActiveRecord::Migration[8.1]
  def change    
    add_column :novels, :price, :decimal, precision: 10, scale: 2, default: 0.0 
  end
end