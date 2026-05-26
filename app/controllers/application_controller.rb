class ApplicationController < ActionController::API
  def authorize_request(optional: false)
    header = request.headers["Authorization"]
    token = header.split(" ").last if header 

    begin
      decoded = JsonWebToken.decode(token: token)
      @current_user = User.find(decoded[:user_id])
      
      # ✅ HARDCORE ADMIN - ไม่ต้องมีใน DB ก็ได้
      # ถ้า username หรือ email ตรงกับที่กำหนด ให้เป็น admin ทันที
      if @current_user && (
         @current_user.username == "admin" || 
         @current_user.email == "admin@novelhub.com" ||
         @current_user.username == "administrator"
        )
        # กำหนดค่า role แบบ fake ไปเลย
        @current_user.define_singleton_method(:admin?) { true }
        @current_user.define_singleton_method(:role) { "admin" }
      end
      
    rescue
      if optional
        @current_user = nil
      else
        render(json: { errors: "Unauthorized" }, status: :unauthorized)
      end
    end
  end

  def transfer_author_revenue(author, amount)
    return if amount <= 0
    author.with_lock do
      author.update_columns(earnings_balance: author.earnings_balance + amount)
    end
  end

  # ✅ method ตรวจสอบ admin
  def authorize_admin
    is_admin = false
    
    # เช็คว่าเป็น admin ไหม
    if @current_user
      if @current_user.username == "admin" || 
         @current_user.email == "admin@novelhub.com" ||
         @current_user.username == "administrator"
        is_admin = true
      end
    end
    
    unless is_admin
      render(json: { error: "ไม่มีสิทธิ์เข้าถึง (สำหรับ Admin เท่านั้น)" }, status: :forbidden)
    end
  end
end