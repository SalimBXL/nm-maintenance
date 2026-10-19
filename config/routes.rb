Rails.application.routes.draw do
  root 'dashboard#show'
  get 'tableau-de-bord', to: 'dashboard#show', as: :dashboard
  get 'up' => 'rails/health#show', as: :rails_health_check

  resources :equipments do
    member do
      post :archive
      post :unarchive
    end
  end

  resources :incidents, except: :destroy do
    member do
      post :transition
    end
  end

  resources :events, path: 'interventions', except: :destroy do
    member do
      post :transition
    end
  end

  resources :documents, except: :destroy do
    member do
      get :download
      get :new_version
      post :create_version
      post :archive
      post :unarchive
    end
  end

  resource :session
  resources :passwords, param: :token

  namespace :admin do
    resources :departments, :locations, :equipment_categories, :manufacturers, :equipment_models,
              except: :show do
      member do
        post :archive
        post :unarchive
      end
    end
    resources :users, except: :show do
      member do
        post :deactivate
        post :reactivate
      end
    end
  end

  resources :api_tokens, path: 'jetons-api', only: %i[index new create destroy]

  namespace :api do
    namespace :v1, defaults: { format: :json } do
      get 'me', to: 'me#show'
      get 'openapi.yaml', to: 'openapi#show', as: :openapi, format: false

      resources :equipments, only: %i[index show]

      resources :incidents, only: %i[index show create] do
        member { post :transition }
      end

      resources :events, only: %i[index show create] do
        member do
          post :start
          post :complete
          post :cancel
        end
      end
    end
  end
end
