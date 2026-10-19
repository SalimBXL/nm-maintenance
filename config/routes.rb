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
end
