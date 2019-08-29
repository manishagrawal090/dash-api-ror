Rails.application.routes.draw do

  namespace :api do
    namespace :v1 do
      devise_for :users,:controllers => {passwords: 'api/v1/passwords', registrations: 'api/v1/registrations'},
        :skip => [:sessions,:registrations,:passwords]
      devise_scope :api_v1_user do
        post '/users' => 'registrations#create', :as => 'user_registration'
        post '/users/password' => 'passwords#create', :as => 'user_password'
        put '/users/password' => 'passwords#update', :as => 'new_user_password'
        get '/users' => 'users#index'
      end

      use_doorkeeper do
        skip_controllers :authorizations, :applications,
                         :authorized_applications
        controllers :tokens => 'tokens',:token_info => 'token_info'
      end

      resources :users,only:[] do
        collection do
          get  'profile', to: 'users#profile'
          put  'profile', to: 'users#update'
          put  'change_status', to: 'users#change_status'
        end
      end
    end
  end

  # swagger routes for api
  get '/api' => redirect('/swagger-ui-2.2.10/dist/index.html?url=/apidocs/api-docs.json')
  root :to => "application#api"
end
