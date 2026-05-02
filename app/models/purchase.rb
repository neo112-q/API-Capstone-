class Purchase < ApplicationRecord
  belongs_to(:user)
  belongs_to(:novel)

  before_validation(:calculate_fees, if: :price_changed?)

  private

  def calculate_fees
    if price.present? && price > 0
      self.platform_fee = (price * 0.4).to_i
      self.author_revenue = price - self.platform_fee
    end
  end
end