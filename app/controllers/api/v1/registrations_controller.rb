module Api
  module V1
    class RegistrationsController < Devise::RegistrationsController
      include Swagger::Docs::Methods

      swagger_controller :registrations, 'Registrations',resource_path: 'Authentication and Password Management'

      swagger_api :create do |api|
        summary 'Registration'
        param :form, 'user[first_name]', :string, :required, 'First Name'
        param :form, 'user[last_name]', :string, :required, 'Last Name'
        param :form, 'user[email]', :string, :required, 'Email'
        param :form, 'user[password]',:string, :required, 'Password','format': 'password'
        param :form, 'user[password_confirmation]', :string, :required, 'Password Confirmation','format': 'password'
        Api::V1::BaseController::response(api)
      end

      def create
        user = User.create(user_params)
        if user.save
          response = { message: 'User created successfully'}
          render json: response, status: :created
        else
          render json: user.errors, status: :bad
        end
      end

      private

      def user_params
        params.require(:user).permit(
          :first_name, :last_name,:email,
          :password,:password_confirmation
        )
      end
    end
  end
end
