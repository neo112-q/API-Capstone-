Rails.application.routes.draw do
  namespace(:api) do
    namespace(:v1) do
      # ส่วนของนิยาย
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

        post("toggle_like", to: "likes#toggle")
        post("purchase", to: "purchases#create")

        # ส่วนของchapters
        resources(:chapters, only: [:index, :create, :update, :destroy, :show]) do
          post("toggle_like", to: "likes#toggle")
          member do
            post("unlock", to: "chapters#unlock")
          end
        end
      end
      resources(:reading_histories, only: [:index, :destroy]) do
        collection do
          post("save", to: "reading_histories#create")
        end
      end

      # ส่วนของ User และระบบเงิน
      scope(:user) do
        post("sign-up", to: "users#sign_up")
        post("sign-in", to: "users#sign_in")
        delete("delete", to: "users#destroy")

        get("profile", to: "users#profile")
        patch("profile", to: "users#update_profile")
        patch("password", to: "users#update_password")

        post("topup/intent", to: "payments#create_intent")
      end
      # ระบบ Stripe Webhook
      post("webhooks/stripe", to: "payments#stripe_webhook")
    end
  end
end
