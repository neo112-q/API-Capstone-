class ApplicationController < ActionController::API
  def authorize_request(optional: false)
    header = request.headers["Authorization"]
    token = header.split(" ").last if header 

    begin
      decoded = JsonWebToken.decode(token: token)
      @current_user = User.find(decoded[:user_id])
    rescue
      if optional
        @current_user = nil
      else
        render(json: { errors: "Unauthorized" }, status: :unauthorized)
      end
    end
  end
end