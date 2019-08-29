class Api::V1::TokensController < Doorkeeper::TokensController
  include Swagger::Docs::Methods

  swagger_controller :tokens, 'Tokens',resource_path: 'Authentication and Password Management'

  swagger_api :create do |api|
    summary 'Login'
    param :form, :email, :string, :required, 'Email'
    param :form, :password, :string, :required, 'Password','format': 'password'
    param :form, :grant_type, :string,:required,"value is => 'password'", 'enum': ['password']
    Api::V1::BaseController::response(api)
  end

  swagger_api :revoke do |api|
    summary 'Logout'
    notes 'Authorization = Bearer {access_token}'
    Api::V1::BaseController::header_authorization(api)
    param :form, :token, :string, :required, 'Token'
    Api::V1::BaseController::response(api)
  end

  def create
    user = User.find_by_email(params[:email])
    if user.present?
      if user.active?
        super
      else
        render json: {:success=>false, message: 'User is inactive'}
      end
    else
      render json: {:success=>false, message: 'Invalid email or password.'}
    end
  end

  def revoke
    revoke_token if authorized?
    render json: {:success=>true, message: 'Logout successfully'}
  end
end
