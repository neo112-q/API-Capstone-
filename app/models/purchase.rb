class Purchase < ApplicationRecord
  belongs_to(:user)
  belongs_to(:novel)

  before_validation(:calculate_fees)

  private

  def calculate_fees()
    if price.present?
      self.platform_fee = price * 0.40
      self.author_revenue = price - self.platform_fee
    end
  end
end