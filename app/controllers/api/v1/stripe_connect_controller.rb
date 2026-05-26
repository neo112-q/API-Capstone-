class Api::V1::StripeConnectController < ::ApplicationController
  before_action :authorize_request

  def onboard
    if @current_user.stripe_account_id.present? && @current_user.stripe_charges_enabled
      account = retrieve_stripe_account
      if account && account.charges_enabled
        return render(json: {
          status: 'connected',
          message: 'คุณเชื่อมต่อ Stripe แล้ว',
          stripe_account_id: @current_user.stripe_account_id
        }, status: :ok)
      end
    end

    account = if @current_user.stripe_account_id.present?
                acc = retrieve_stripe_account
                acc if acc
              end

    account ||= Stripe::Account.create({
      type: 'express',
      country: 'TH',
      email: @current_user.email,
      capabilities: {
        transfers: { requested: true }
      },
      business_type: 'individual',
      tos_acceptance: { service_agreement: 'recipient' }
    })

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

    account = retrieve_stripe_account
    if account.nil?
      return render(json: {
        connected: false,
        earnings_balance: @current_user.earnings_balance
      }, status: :ok)
    end

    charges_enabled = account.charges_enabled

    @current_user.update_columns(stripe_charges_enabled: charges_enabled) if charges_enabled != @current_user.stripe_charges_enabled

    render(json: {
      connected: charges_enabled,
      onboarding_incomplete: !charges_enabled && account.details_submitted != true,
      stripe_account_id: @current_user.stripe_account_id,
      earnings_balance: @current_user.earnings_balance,
      charges_enabled: charges_enabled
    }, status: :ok)

  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe status error: #{e.message}"
    render(json: {
      connected: false,
      earnings_balance: @current_user.earnings_balance,
      error: e.message
    }, status: :ok)
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
    clear_stripe_if_invalid(e)
    render(json: { error: e.message }, status: :bad_request)
  end

  def payout
    if @current_user.stripe_account_id.blank? || !@current_user.stripe_charges_enabled
      return render(json: { error: 'คุณยังไม่ได้เชื่อมต่อ Stripe' }, status: :bad_request)
    end

    amount_coins = params[:amount].to_i
    payout_options = [1000, 2000, 5000, 10000]

    unless payout_options.include?(amount_coins)
      return render(json: { error: 'จำนวนถอนไม่ถูกต้อง กรุณาเลือกจากตัวเลือกที่กำหนด', allowed: payout_options }, status: :unprocessable_entity)
    end

    if @current_user.earnings_balance < amount_coins
      return render(json: { error: 'ยอดรายได้ของคุณไม่เพียงพอสำหรับการถอน', balance: @current_user.earnings_balance }, status: :unprocessable_entity)
    end

    amount_thb = amount_coins

    payout_record = @current_user.payouts.new(
      amount_coins: amount_coins,
      amount_thb: amount_thb,
      status: 'pending'
    )

    begin
      transfer = Stripe::Transfer.create({
        amount: amount_thb * 100,
        currency: 'thb',
        destination: @current_user.stripe_account_id,
        metadata: {
          user_id: @current_user.id,
          coin_amount: amount_coins
        }
      })

      payout_record.stripe_transfer_id = transfer.id
      payout_record.status = 'completed'

      ActiveRecord::Base.transaction do
        payout_record.save!
        @current_user.update!(earnings_balance: @current_user.earnings_balance - amount_coins)
      end

      render(json: {
        status: 'completed',
        amount: amount_coins,
        new_balance: @current_user.earnings_balance,
        transfer_id: transfer.id,
        message: "ถอน #{amount_coins} เหรียญสำเร็จ (ประมาณ #{amount_thb} บาท) เงินจะเข้าบัญชีธนาคารของคุณภายใน 2-7 วันทำการ"
      }, status: :ok)

    rescue Stripe::StripeError => e
      payout_record.status = 'failed'
      payout_record.error_message = e.message
      payout_record.save!

      clear_stripe_if_invalid(e)
      Rails.logger.error "Stripe payout error: #{e.message}"
      render(json: { error: "การโอนเงินล้มเหลว: #{e.message}" }, status: :bad_request)
    end
  end

  def disconnect
    @current_user.update_columns(
      stripe_account_id: nil,
      stripe_charges_enabled: false
    )

    render(json: {
      status: 'disconnected',
      message: 'ยกเลิกการเชื่อมต่อ Stripe แล้ว คุณสามารถเชื่อมต่อใหม่ได้ทันที'
    }, status: :ok)
  end

  def payout_history
    payouts = @current_user.payouts.recent.limit(20)

    render(json: {
      payouts: payouts.map { |p|
        {
          id: p.id,
          amount_coins: p.amount_coins,
          amount_thb: p.amount_thb,
          status: p.status,
          created_at: p.created_at,
          error_message: p.error_message
        }
      }
    }, status: :ok)
  end

  private

  def retrieve_stripe_account
    Stripe::Account.retrieve(@current_user.stripe_account_id)
  rescue Stripe::StripeError => e
    Rails.logger.warn "Stripe account #{@current_user.stripe_account_id} inaccessible: #{e.message}"
    clear_stripe_if_invalid(e)
    nil
  end

  def clear_stripe_if_invalid(error)
    return unless error.is_a?(Stripe::PermissionError) || error.is_a?(Stripe::InvalidRequestError)

    msg = error.message.downcase
    return unless msg.include?('does not have access') || msg.include?('no such account') || msg.include?('does not exist')

    @current_user.update_columns(
      stripe_account_id: nil,
      stripe_charges_enabled: false
    )
  end

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:4200')
  end
end
