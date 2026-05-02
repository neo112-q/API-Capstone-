# config/initializers/stripe.rb
require 'stripe'

Stripe.api_key = ENV['STRIPE_SECRET_KEY']
Stripe.api_version = '2025-02-24.acacia'


STRIPE_WEBHOOK_SECRET = ENV['STRIPE_WEBHOOK_SECRET']

puts "✅ Stripe initialized with key: #{ENV['STRIPE_SECRET_KEY']&.first(20)}..." if Rails.env.development?