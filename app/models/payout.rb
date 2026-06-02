class Payout < ApplicationRecord
  belongs_to :user

  validates :amount_coins, presence: true, numericality: { greater_than: 0 }
  validates :amount_usd, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[pending completed failed] }

  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(created_at: :desc) }
end
