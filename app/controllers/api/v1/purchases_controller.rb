class Api::V1::PurchasesController < ::ApplicationController
  before_action(:authorize_request)

  # C ซื้อนิยาย
  def create()
    novel = Novel.find(params[:novel_id])
    
    price_to_pay = novel.price 

    purchase = @current_user.purchases.new(
      novel: novel, 
      price: price_to_pay
    )

    if purchase.save()
      render(json: { 
        message: "ซื้อนิยายสำเร็จ!", 
        receipt: {
          id: purchase.id,
          total_price: purchase.price,
          platform_fee: purchase.platform_fee, # 40%
          author_revenue: purchase.author_revenue # 60%
        }
      }, status: :created)
    else
      render(json: { errors: purchase.errors.full_messages }, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound
    render(json: { error: "ไม่พบนิยายที่ต้องการซื้อ" }, status: :not_found)
  end
end