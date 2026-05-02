class AddSplitFieldsToUserNovelPurchases < ActiveRecord::Migration[8.1]
  def change
    add_column :user_novel_purchases, :platform_fee, :integer
    add_column :user_novel_purchases, :author_earnings, :integer
  end
end
