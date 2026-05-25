class Api::V1::StripeConnectController < ::ApplicationController
  before_action :authorize_request

  def onboard
    if @current_user.stripe_account_id.present? && @current_user.stripe_charges_enabled
      return render(json: {
        status: 'connected',
        message: 'คุณเชื่อมต่อ Stripe แล้ว',
        stripe_account_id: @current_user.stripe_account_id
      }, status: :ok)
    end

    account = if @current_user.stripe_account_id.present?
                Stripe::Account.retrieve(@current_user.stripe_account_id)
              else
                Stripe::Account.create({
                  type: 'express',
                  country: 'TH',
                  email: @current_user.email,
                  capabilities: {
                    transfers: { requested: true },
                    card_payments: { requested: true }
                  },
                  business_type: 'individual'
                })
              end

    @current_user.update_columns(stripe_account_id: account.id)

    account_link = Stripe::AccountLink.create({
      account: account.id,
      refresh_url: "#{frontend_url}/earnings?stripe=refresh",
      return_url: "#{frontend_url}/earnings?stripe=success",
      type: 'account_onboarding'
    })

    render(json: {
      status: 'onboarding',
      onboarding_url: account_link.url,
      stripe_account_id: account.id
    }, status: :ok)

  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe Connect onboarding error: #{e.message}"
    render(json: { error: e.message }, status: :bad_request)
  end

  def status
    if @current_user.stripe_account_id.blank?
      return render(json: {
        connected: false,
        earnings_balance: @current_user.earnings_balance
      }, status: :ok)
    end

    begin
      account = Stripe::Account.retrieve(@current_user.stripe_account_id)
      charges_enabled = account.charges_enabled

      @current_user.update_columns(stripe_charges_enabled: charges_enabled) if charges_enabled != @current_user.stripe_charges_enabled

      render(json: {
        connected: charges_enabled,
        stripe_account_id: @current_user.stripe_account_id,
        earnings_balance: @current_user.earnings_balance,
        charges_enabled: charges_enabled
      }, status: :ok)
    rescue Stripe::StripeError => e
      render(json: {
        connected: false,
        earnings_balance: @current_user.earnings_balance,
        error: e.message
      }, status: :ok)
    end
  end

  def dashboard
    if @current_user.stripe_account_id.blank?
      return render(json: { error: 'คุณยังไม่ได้เชื่อมต่อ Stripe' }, status: :bad_request)
    end

    login_link = Stripe::Account.create_login_link(@current_user.stripe_account_id)

    render(json: {
      dashboard_url: login_link.url
    }, status: :ok)

  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe dashboard link error: #{e.message}"
    render(json: { error: e.message }, status: :bad_request)
  end

  private

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:4200')
  end
end
