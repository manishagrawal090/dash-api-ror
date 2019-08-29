class ApplicationController < ActionController::API
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_root

  def api
    redirect_to '/api'
  end

  protected

  def set_root
    Rails.application.config.root_url = root_url
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name,:last_name])
  end

  def current_user
    @current_user ||= User.find(doorkeeper_token[:resource_owner_id])
  end

  def doorkeeper_unauthorized_render_options(error: nil)
    { json: {:success=>false, error: 'Unauthorized token' } }
  end

end

