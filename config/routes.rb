Rails.application.routes.draw do
  namespace(:api) do
    namespace(:v1) do
      resources(:novels) do
        resources(:chapters, only: [ :index, :create, :update, :destroy ])
      end
      scope(:user) do
        post("sign-up", to: "users#sign_up")
        post("sign-in", to: "users#sign_in")
        delete("delete", to: "users#destroy")
      end
    end
  end
end
