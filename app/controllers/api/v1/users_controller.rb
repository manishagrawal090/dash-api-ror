class Api::V1::UsersController < Api::V1::BaseController
  include Swagger::Docs::Methods

  swagger_controller :users, 'users',resource_path: 'User Management'

  swagger_api :index do |api|
    summary 'Listing of users'
    notes 'Authorization = Bearer {access_token}'
    Api::V1::BaseController::header_authorization(api)
    Api::V1::BaseController::response(api)
  end

  swagger_api :profile do |api|
    summary 'Get profile'
    notes 'Authorization = Bearer {access_token}'
    Api::V1::BaseController::header_authorization(api)
    Api::V1::BaseController::response(api)
  end

  swagger_api :update do |api|
    summary 'Update profile'
    notes 'Authorization = Bearer {access_token}'
    Api::V1::BaseController::header_authorization(api)
    param :form, 'user[first_name]', :string, :optional, 'First Name'
    param :form, 'user[last_name]', :string, :optional, 'Last Name'
    param :form, 'user[avatar]', :string, :optional, 'Upload image'
    param :form, 'user[avatar_delete]', :boolean, :optional, 'Delete image', 'defaultValue': 'false'
    Api::V1::BaseController::response(api)
  end

  swagger_api :change_status do |api|
    summary 'Update user status'
    notes 'Authorization = Bearer {access_token}'
    Api::V1::BaseController::header_authorization(api)
    param :form, 'user[id][]',:array,:required,'User id'
    param :form, 'user[status]',:string,:required,'User id',enum: ['active','inactive']
    Api::V1::BaseController::response(api)
  end

  def index
    if current_user.has_role? :admin
      users = User.all.map do |user|
        user.remove_column_merge.except('roles')
      end
      result = {:success=>true, :users=>users}
      render json: result
    else
      render json: {:success=>false, message: 'User not permitted'}
    end
  end

  def profile
    result = {
        :success=>true,
        :data=>current_user.remove_column_merge }
    render json: result
  end

  def update
    user = current_user
    user.avatar_base64 = params[:user][:avatar]
    user.avatar_delete = params[:user][:avatar_delete]
    if user.update(update_params)
      render json: {:success=>true, message: 'Profile update successfully'}
    else
      render json: {:success=>false}
    end
  end

  def change_status
    if current_user.has_role? :admin
      if params[:user][:id].reject(&:blank?).present?
        id = params[:user][:id].select {|s| s =~ /^[0-9]+$/}
        if id.present?
          users = User.where(id: id)
          if users.present?
            if User.statuses.include?(params[:user][:status])
              users.update(status: params[:user][:status])
              render json: {:success=>true, message: 'User status change successfully'}
            else
              render json: {:success=>false, message: 'User status is invalid'}
            end
          end
        else
          render json: {:success=>false, message: 'User id is invalid'}
        end
      else
        render json: {:success=>false, message: 'User id parameter is required'}
      end
    else
      render json: {:success=>false, message: 'User not permitted'}
    end
  end

  private

  def update_params
    params.require(:user).permit(
        :first_name,:last_name,:avatar
    )
  end
end
