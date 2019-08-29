class Api::V1::BaseController < ApplicationController
  before_action :doorkeeper_authorize!

  def self.header_authorization(api)
    api.param :header, :Authorization, :string, :required, 'Header Token'
  end

  def self.response(api)
    api.response :unauthorized
    api.response :not_acceptable, 'The request you made is not acceptable'
  end

end