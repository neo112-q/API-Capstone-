class Payment < ApplicationRecord
  belongs_to :user

  validates :stripe_payment_intent_id, presence: true, uniqueness: true
end