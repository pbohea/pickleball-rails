Rails.application.routes.draw do
  devise_for :users

  root to: "pages#home"
  get "menu" => "pages#menu"
  get "dashboard" => "videos#index"
  get "upload" => "videos#new"

  resources :videos, only: [:index, :new, :create, :show] do
    member do
      get :status
    end
    collection do
      post :native_upload
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
