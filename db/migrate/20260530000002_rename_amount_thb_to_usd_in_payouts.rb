class RenameAmountThbToUsdInPayouts < ActiveRecord::Migration[8.1]
  def change
    if table_exists?(:payouts) && column_exists?(:payouts, :amount_thb)
      rename_column :payouts, :amount_thb, :amount_usd
      change_column :payouts, :amount_usd, :decimal, precision: 10, scale: 2
    end
  end
end
