Rails.application.routes.draw do
  namespace(:api) do
    namespace(:v1) do
      post 'forgot_password', to: 'passwords#forgot'
      post 'reset_password', to: 'passwords#reset'
      resources(:novels) do
        collection do
          get("my_novels", to: "novels#my_novels")
          get("genres", to: "novels#genres_list")
          get("following", to: "follows#index")
        end

        member do
          post("follow", to: "follows#create")
          delete("unfollow", to: "follows#destroy")
        end

        post("purchase", to: "purchases#create")

        # ส่วนของchapters
        resources(:chapters, only: [:index, :create, :update, :destroy, :show]) do

          resources(:comments, only: [:index, :create, :destroy])
          member do
            post("toggle_like", to: "likes#toggle")
            post("unlock", to: "chapters#unlock")
          end
        end
      end

      resources(:reading_histories, only: [:index, :create, :destroy])

      get("user/liked_chapters", to: "users#liked_chapters")

      get("users/:user_id/unlocked_chapters", to: "users#unlocked_chapters")

      scope(:user) do
        post("sign-up", to: "users#sign_up")
        post("sign-in", to: "users#sign_in")
        delete("delete", to: "users#destroy")

        get("profile", to: "users#profile")
        patch("profile", to: "users#update_profile")
        patch("password", to: "users#update_password")

        post("topup/intent", to: "payments#create_intent")
        post("topup/create-checkout-session", to: "payments#create_checkout_session")

        post("connect/onboarding", to: "payments#connect_onboarding")
      end

      post("webhooks/stripe", to: "payments#stripe_webhook")
    end
  end
end
