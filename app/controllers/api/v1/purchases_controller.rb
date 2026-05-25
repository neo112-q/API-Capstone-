class Api::V1::PurchasesController < ::ApplicationController
  before_action(:authorize_request)

  def create()
    novel = Novel.find(params[:novel_id])
    price_to_pay = novel.price 
    purchase = nil 

    ActiveRecord::Base.transaction do
      if @current_user.coin_balance < price_to_pay
        return render(json: { error: "เหรียญไม่พอ" }, status: :payment_required)
      end
      
      @current_user.update!(coin_balance: @current_user.coin_balance - price_to_pay)
      
      purchase = @current_user.purchases.new(
        novel: novel, 
        price: price_to_pay
      )
      purchase.save!
      
      author = novel.user
      author.update!(earnings_balance: author.earnings_balance + purchase.author_revenue)
    end

    # ✅ reload ให้ได้ค่าล่าสุด
    @current_user.reload

    render(json: { 
      message: "ซื้อนิยายสำเร็จ!", 
      balance: @current_user.coin_balance,
      receipt: {
        id: purchase.id,
        total_price: purchase.price,
        platform_fee: purchase.platform_fee,
        author_revenue: purchase.author_revenue
      }
    }, status: :created)
  end
end