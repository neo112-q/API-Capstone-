# app/controllers/api/v1/payments_controller.rb
class Api::V1::PaymentsController < ::ApplicationController
  skip_before_action(:verify_authenticity_token, only: [:stripe_webhook], raise: false)
  before_action(:authorize_request, except: [:stripe_webhook, :success, :cancel])
  
  # ✅ สร้าง Checkout Session (ที่ Frontend เรียก)
  def create_checkout_session
    amount = params[:amount].to_i
    success_url = params[:success_url] || "#{request.base_url}/topup/success"
    cancel_url = params[:cancel_url] || "#{request.base_url}/topup"
    
    if amount < 10
      return render(json: { error: "จำนวนเงินขั้นต่ำ 10 บาท" }, status: :unprocessable_entity)
    end
    
    begin
      session = Stripe::Checkout::Session.create({
        payment_method_types: ['card', 'promptpay'],
        line_items: [{
          price_data: {
            currency: 'thb',
            product_data: {
              name: 'เติมเหรียญสำหรับอ่านนิยาย',
              description: "รับ #{amount} เหรียญ (1 บาท = 1 เหรียญ)",
              images: ['https://your-domain.com/coin-icon.png'] # ใส่รูปถ้ามี
            },
            unit_amount: amount * 100, # Stripe ใช้สตางค์ (บาท * 100)
          },
          quantity: 1,
        }],
        mode: 'payment',
        success_url: success_url,
        cancel_url: cancel_url,
        metadata: {
          user_id: @current_user.id,
          coin_amount: amount,
          type: 'topup'
        },
        locale: 'th'
      })
      
      render(json: { url: session.url }, status: :ok)
      
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe Error: #{e.message}"
      render(json: { error: e.message }, status: :bad_request)
    end
  end
  
  # ฟังก์ชันเก่า (optional - ไว้ใช้ในอนาคต)
  def create_intent
    coin_amount = params[:coin_amount].to_i
    return render(json: { error: "จำนวนเหรียญไม่ถูกต้อง" }, status: :unprocessable_entity) if coin_amount <= 0

    total_price_thb = coin_amount.round(2)

    begin
      intent = Stripe::PaymentIntent.create({
        amount: (total_price_thb * 100).to_i,
        currency: "thb",
        metadata: { 
          user_id: @current_user.id, 
          coin_amount: coin_amount,
          fee_added: "0%"
        }
      })

      render(json: { 
        client_secret: intent.client_secret,
        total_to_pay: total_price_thb,
        coins_to_receive: coin_amount
      }, status: :ok)

    rescue Stripe::StripeError => e
      render(json: { error: e.message }, status: :bad_request)
    end
  end

  def stripe_webhook
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    webhook_secret = ENV['STRIPE_WEBHOOK_SECRET']
    
    Rails.logger.info "=== Webhook Received ==="
    Rails.logger.info "Event Type: Checking..."
    
    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
      Rails.logger.info "✅ Webhook verified: #{event.type}"
      
      case event.type
      when 'checkout.session.completed'
        session = event.data.object
        
        # ✅ ตรวจสอบว่า session นี้จ่ายเงินสำเร็จ
        if session.payment_status == 'paid'
          user_id = session.metadata.user_id
          coin_amount = session.metadata.coin_amount.to_i
          
          Rails.logger.info "Processing payment: user_id=#{user_id}, coins=#{coin_amount}"
          
          # ✅ อัพเดทเหรียญ
          user = User.find_by(id: user_id)
          if user
            user.update_columns(coin_balance: user.coin_balance + coin_amount)
            Rails.logger.info "✅ Added #{coin_amount} coins to user #{user_id}. New balance: #{user.coin_balance}"
          else
            Rails.logger.error "❌ User not found: #{user_id}"
          end
        end
        
      when 'payment_intent.succeeded'
        payment_intent = event.data.object
        user_id = payment_intent.metadata.user_id
        coin_amount = payment_intent.metadata.coin_amount.to_i
        
        user = User.find_by(id: user_id)
        if user
          user.update_columns(coin_balance: user.coin_balance + coin_amount)
          Rails.logger.info "✅ Added #{coin_amount} coins via PaymentIntent"
        end
      end
      
      render(json: { status: 'success' }, status: :ok)
      
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "❌ Webhook signature verification failed: #{e.message}"
      render(json: { error: 'Invalid signature' }, status: :bad_request)
    rescue => e
      Rails.logger.error "❌ Webhook error: #{e.message}"
      render(json: { error: e.message }, status: :internal_server_error)
    end
  end
  
  # ✅ เพิ่ม endpoint สำหรับ success page
  def success
    # หน้า success จะถูกจัดการโดย frontend
    # แค่ render JSON เพื่อให้ frontend รู้ว่า success
    render(json: { status: 'success', message: 'เติมเหรียญสำเร็จ' }, status: :ok)
  end
  
  def cancel
    render(json: { status: 'cancelled', message: 'ยกเลิกการเติมเหรียญ' }, status: :ok)
  end
end