Rails.application.routes.draw do

  # Apple App Site Association (no .json extension)
  get "/.well-known/apple-app-site-association", to: "well_known#apple"

  devise_for :users, controllers: {
                       sessions: "users/sessions",
                       registrations: "users/registrations",
                       passwords: "users/passwords",
                       confirmations: "users/confirmations",
                       unlocks: "users/unlocks",
                     }

  devise_for :owners, controllers: {
                        sessions: "owners/sessions",
                        registrations: "owners/registrations",
                        passwords: "owners/passwords",
                        confirmations: "owners/confirmations",
                        unlocks: "owners/unlocks",
                      }

  devise_for :artists, controllers: {
                         sessions: "artists/sessions",
                         registrations: "artists/registrations",
                         passwords: "artists/passwords",
                         confirmations: "artists/confirmations",
                         unlocks: "artists/unlocks",
                       }
  devise_for :promoters, controllers: {
                        sessions: "promoters/sessions",
                        registrations: "promoters/registrations",
                        passwords: "promoters/passwords",
                        confirmations: "promoters/confirmations",
                        unlocks: "promoters/unlocks",
                      }
                    

  root to: "pages#home"

  get "map", to: "events#map_landing"
  get "events/map", to: "events#map"

  resources :venues do
    get :search, on: :collection
    member do
      get :upcoming_events
      get :check_ownership
    end
  end

  get "events/landing", to: "events#landing"

  resources :events do
    collection do
      #get :nearby
      get :map
      get :landing
      get :time_options_ajax
      get :end_time_options_ajax
      get :date_options_ajax
      get :conflicts_ajax
    end
  end

  resources :artists, only: [:show] do
    get :events, on: :member
    get :promo_flyer, on: :member
    get :promo_flyer_print, on: :member
    get :search, on: :collection
  end

  resources :artist_follows, only: [:create, :destroy]

  resources :venue_follows, only: [:create, :destroy]

  resources :artist_leads, only: [:new, :create]
  get "/artist_leads/thank_you", to: "artist_leads#thank_you", as: :artist_lead_thank_you
  get "/artist_leads/claim/:token", to: "artist_leads#claim", as: :claim_artist_lead

  # new venue requests (public)
  resources :venue_requests, only: [:index, :new, :create, :destroy] do
    get :claim, on: :collection
    get :receipt, on: :member
  end

  # admin-only
  namespace :admin do
    # Venues: keep full REST, add owner-management member actions
    resources :venues do
      member do
        get :edit_owner
        patch :update_owner
        delete :remove_owner
      end
    end

    # Lightweight owner search for autocomplete in admin (optional)
    resources :owners, only: [] do
      collection do
        get :lookup   # /admin/owners/lookup?q=...
      end
    end

    # Venue Requests: preserve your original member actions
    resources :venue_requests do
      member do
        patch :approve
        patch :reject
        patch :update_coordinates
      end
    end

    resources :event_imports, only: [:index, :show, :create] do
      member do
        post :approve_all
        get :approve_summary
      end
      resources :event_import_rows, only: [:destroy] do
        post :approve, on: :member
      end
    end

  end

  resources :configurations, only: [] do
    get :ios_v1, on: :collection
  end

  resources :notification_tokens, only: :create

  #misc routes
  # User-specific routes (no ID needed - uses current_user/current_owner/current_artist)
  get "/owner/dashboard", to: "owners#dashboard", as: :owner_dashboard
  get "/user/dashboard", to: "users#dashboard", as: :user_dashboard
  get "/artist/dashboard", to: "artists#dashboard", as: :artist_dashboard
  get "/owner/venue_requests", to: "owners#venue_requests", as: "owner_venue_requests"
  get "/artist/venue_requests", to: "artists#venue_requests", as: "artist_venue_requests"
  get "/about", to: "pages#about"
  get "/owners_about", to: "pages#owners_about"
  get "/artists_about", to: "pages#artists_about"
  get "/menu", to: "pages#menu", as: :menu
  get "/users/:id/landing", to: "users#landing", as: :user_landing
  get "/artists/:id/landing", to: "artists#landing", as: :artist_landing
  get "/owners/:id/landing", to: "owners#landing", as: :owner_landing
  get "/privacy", to: "pages#privacy", as: :privacy
  get "/search", to: "pages#home_search"

  #promoters
  get "/promoter/dashboard", to: "promoters#dashboard", as: :promoter_dashboard
  get "/promoter/artists",   to: "promoters/artists#index", as: :promoter_artists
  get "/promoter/venues",    to: "promoters/venues#index",  as: :promoter_venues
  
  #feedback 
  get "/feedback", to: "pages#feedback", as: :feedback
  post "/feedback", to: "pages#submit_feedback", as: :submit_feedback
  get "/thank-you", to: "pages#thank_you", as: :thank_you
  
  # Admin routes
  get "/admin", to: "admin#dashboard", as: "admin_dashboard"
  get "/admin/metrics", to: "admin#metrics", as: "admin_metrics"
  #get "/admin/venue_requests", to: "admin#venue_requests", as: "admin_venue_requests"

  get "/test_email", to: "test_email#send_ping"

  #for autocomplete search
  get "/artists/search", to: "artists#search"
  

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  #render rake tasks

  get("/rake_tasks", { :controller => "rake_tasks", :action => "show" })
  get("/run_task", { :controller => "rake_tasks", :action => "run_task" })
end
