module Api
  module V1
    class PasswordsController < Devise::PasswordsController
      include Swagger::Docs::Methods

      swagger_controller :passwords, 'Passwords',resource_path: 'Authentication and Password Management'

      swagger_api :create do |api|
        summary 'Forgot password'
        param :form, 'user[email]', :string, :required, 'Email'
        Api::V1::BaseController::response(api)
      end

      swagger_api :update do |api|
        summary 'Change password'
        param :form, 'user[reset_password_token]', :string, :required, 'Token'
        param :form, 'user[password]', :string, :required, 'New Password','format': 'password'
        param :form, 'user[password_confirmation]', :string, :required, 'New Confirm password','format': 'password'
        Api::V1::BaseController::response(api)
      end

      def create
        user = User.find_by_email(params[:user][:email])
        if user.present?
          user.send_reset_password_instructions
          render json: {:success=>true, message: 'Mail sent successfully'}
        else
          render json: {:success=>false, message: 'Email not found'}
        end
      end

      def update
        user = User.with_reset_password_token(params[:user][:reset_password_token])
        if user.present?
          if user.update_attributes(resource_params)
            render json: {:success=>true, message: 'Password change successfully'}
          else
            render json: {:success=>false, message: 'Password not match'}
          end
        else
          render json: {:success=>false, message: 'Token not match'}
        end
      end

      def resource_params
        params.require(:user).permit(
          :password,:password_confirmation
        )
      end
     end
  end
end