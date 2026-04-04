Rails.application.routes.draw do
  namespace(:api) do
    namespace(:v1) do
      scope(:user) do
        post("sign-up", to: "users#sign_up")
        post("sign-in", to: "users#sign_in")
        delete("delete", to: "users#destroy")
      end
      # เพิ่มพวก index, show, create, update, delete
      resources(:novels)
    end
  end
end
