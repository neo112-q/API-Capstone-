class Api::V1::UsersController < ApplicationController
    def sign_up()
    user = User.new(sign_up_params())

    if user.save()
      token = JsonWebToken.encode(payload: { user_id: user.id })
      render(json: {
        message: "Sign up successful",
        token: token,
        user: user_as_json(user)
      }, status: :created)
    else
      render(json: { 
        message: "Sign up failed", 
        errors: user.errors.full_messages 
      }, status: :unprocessable_entity)
    end
  end

  def sign_in()
    user = User.find_by(email: params[:identifier]&.downcase()) || 
           User.find_by(username: params[:identifier]&.downcase())

    if user&.authenticate(params[:password])
      token = JsonWebToken.encode(payload: { user_id: user.id })
      render(json: {
        message: "Sign in successful",
        token: token,
        user: user_as_json(user)
      }, status: :ok)
    else
      render(json: { message: "Invalid email/username or password" }, status: :unauthorized)
    end
  end


  def destroy()
    user = User.find_by(email: params[:identifier]&.downcase()) || 
           User.find_by(username: params[:identifier]&.downcase())

    if user
      if user.authenticate(params[:password])
        user.destroy()
        render(json: { message: "User deleted successfully" }, status: :ok)
      else
        render(json: { message: "Invalid password, cannot delete" }, status: :unauthorized)
      end
    else
      render(json: { message: "User not found" }, status: :not_found)
    end
  end

  private 

  def sign_up_params()
    params.require(:user).permit(:email, :username, :password, :password_confirmation)
  end

  def user_as_json(user)
    {
      id: user.id,
      email: user.email,
      username: user.username,
      created_at: user.created_at
    }
  end
end