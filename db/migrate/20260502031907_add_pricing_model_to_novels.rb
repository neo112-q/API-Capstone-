class AddPricingModelToNovels < ActiveRecord::Migration[8.1]
  def change
    add_column :novels, :pricing_model, :string, default: 'free'
    add_column :novels, :early_access_days, :integer, default: 7
    add_column :novels, :per_chapter_price, :integer, default: 0
  end
end