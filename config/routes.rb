Rails.application.routes.draw do
  namespace(:api) do
    namespace(:v1) do
      
      resources(:novels) do
        collection do
          get("genres", to: "novels#genres_list")
        end
        
        resources(:chapters, only: [ :index, :create, :update, :destroy, :show ])
      end
      
      scope(:user) do
        post("sign-up", to: "users#sign_up")
        post("sign-in", to: "users#sign_in")
        delete("delete", to: "users#destroy")

        get("profile", to: "users#profile")
        patch("profile", to: "users#update_profile")
        patch("password", to: "users#update_password")
      end
      
    end
  end
end