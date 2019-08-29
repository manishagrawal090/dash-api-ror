class Api::V1::TokenInfoController < Doorkeeper::TokenInfoController
  include Swagger::Docs::Methods

  swagger_controller :token_info, 'Token_info',resource_path: 'Authentication and Password Management'

  swagger_api :show do |api|
    summary 'Check token expiry'
    notes 'Authorization = Bearer {access_token}'
    Api::V1::BaseController::header_authorization(api)
    Api::V1::BaseController::response(api)
  end

  def show
    if doorkeeper_token && doorkeeper_token.accessible?
      render json: {:success=>true, expires_in: doorkeeper_token.expires_in}
    else
      render json:  {:success=>false, message: 'Token is invalid or expired' }
    end
  end
end
