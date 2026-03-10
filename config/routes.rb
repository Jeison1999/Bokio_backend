Rails.application.routes.draw do
  # API v1 routes
  namespace :api do
    namespace :v1 do
      # Auth routes
      devise_scope :user do
        post 'auth/sign_up', to: 'auth/registrations#create'
        post 'auth/sign_in', to: 'auth/sessions#create'
        delete 'auth/sign_out', to: 'auth/sessions#destroy'
      end

      # Business routes
      resources :businesses do
        collection do
          get 'by_slug/:slug', to: 'businesses#by_slug', as: :by_slug
        end

        # Stats routes for business (admin/employee access)
        get 'stats', to: 'stats#index'
        get 'stats/dashboard', to: 'stats#dashboard'
        get 'stats/revenue', to: 'stats#revenue'
        get 'stats/employees/:employee_id', to: 'stats#employee_stats'
        
        resources :employees do
          member do
            post :assign_services
          end
        end
        resources :services
        resources :tickets do
          member do
            post :start
            post :complete
            post :cancel
            post :no_show
            patch :mark_as_paid
          end
          collection do
            get :queue
          end
        end
      end
      
      # Admin routes (super_admin only)
      namespace :admin do
        get 'stats/overview', to: 'stats#overview'
        get 'stats/businesses', to: 'stats#businesses'
        get 'stats/revenue', to: 'stats#revenue'
        get 'stats/subscriptions', to: 'stats#subscriptions'
      end
      
      # Notification routes
      resources :notifications, only: [:index] do
        member do
          patch :mark_as_read
        end
        collection do
          get :unread
          post :mark_all_as_read
        end
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Mount ActionCable for WebSocket connections
  mount ActionCable.server => '/cable'

  # Defines the root path route ("/")
  # root "posts#index"
end
