class Api::V1::PaymentsController < ::ApplicationController
  # ยกเว้นการตรวจ CSRF เฉพาะตอน Stripe ยิงมา
  skip_before_action(:verify_authenticity_token, only: [:stripe_webhook], raise: false)
  # สั่งตรวจ Token ของ User ทุกเส้นยกเว้น Webhook
  before_action(:authorize_request, except: [:stripe_webhook])

  # API 1: สร้างใบแจ้งหนี้
  def create_intent()
    coin_amount = params[:coin_amount].to_i
    return render(json: { error: "จำนวนเหรียญไม่ถูกต้อง" }, status: :unprocessable_entity) if coin_amount <= 0

    fee_multiplier = 1.0
    total_price_thb = (coin_amount * fee_multiplier).round(2)

    begin
      intent = Stripe::PaymentIntent.create({
        amount: (total_price_thb * 100).to_i, # Stripe รับเป็นสตางค์
        currency: "thb",
        metadata: { 
          user_id: @current_user.id, 
          coin_amount: coin_amount, # เก็บจำนวนเหรียญที่จะให้ไว้ใน metadata
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

  # API 2 Webhook รับเงินจริง ไม่มีคืนเงินนะจ๊ะ
  def stripe_webhook()
    payload = request.body.read()
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    
    puts "====================================="
    puts "[1] WEBHOOK วิ่งเข้าเซิร์ฟเวอร์แล้ว!"

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, STRIPE_WEBHOOK_SECRET)
      puts "[2] ลายเซ็นถูกต้อง! (Event: #{event.type})"
    rescue JSON::ParserError, Stripe::SignatureVerificationError => e
      puts "[พังที่ข้อ 2] ลายเซ็นไม่ตรง! (ใส่ whsec ผิด หรือไม่ได้ Restart เซิร์ฟเวอร์)"
      puts "Error: #{e.message}"
      return render(json: { error: "Webhook Error" }, status: :bad_request)
    end

    if event.type == "payment_intent.succeeded"
      payment_intent = event.data.object
      user_id = payment_intent.metadata.user_id
      coin_amount = payment_intent.metadata.coin_amount.to_i

      puts "[3] ดึงข้อมูลได้: User ID = #{user_id.inspect}, จำนวนเหรียญ = #{coin_amount.inspect}"

      user = User.find_by(id: user_id)
      
      if user.present?
        ActiveRecord::Base.transaction do
          user.lock!() 
          user.coin_balance += coin_amount
          user.save!()
        end
        puts "[4] บันทึก DB สำเร็จ ! บวก #{coin_amount} เหรียญให้ User #{user.id} แล้ว!"
      else
        puts "[พังที่ข้อ 4] หา User ID #{user_id} ไม่เจอใน Database !!"
      end
    else
       puts "ไม่ใช่ Event จ่ายเงินสำเร็จ (เป็น Event: #{event.type})"
    end
    puts "====================================="

    render(json: { status: "received" }, status: :ok)
  end
end