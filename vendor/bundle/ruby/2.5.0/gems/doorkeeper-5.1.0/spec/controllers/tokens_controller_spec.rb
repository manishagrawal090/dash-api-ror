# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::TokensController do
  describe "when authorization has succeeded" do
    let(:token) { double(:token, authorize: true) }

    it "returns the authorization" do
      skip "verify need of these specs"

      expect(token).to receive(:authorization)

      post :create
    end
  end

  describe "when authorization has failed" do
    it "returns the error response" do
      token = double(:token, authorize: false)
      allow(controller).to receive(:token) { token }

      post :create

      expect(response.status).to eq 400
      expect(response.headers["WWW-Authenticate"]).to match(/Bearer/)
    end
  end

  describe "when there is a failure due to a custom error" do
    it "returns the error response with a custom message" do
      # I18n looks for `doorkeeper.errors.messages.custom_message` in locale files
      custom_message = "my_message"
      allow(I18n).to receive(:translate)
        .with(
          custom_message,
          hash_including(scope: %i[doorkeeper errors messages])
        )
        .and_return("Authorization custom message")

      doorkeeper_error = Doorkeeper::Errors::DoorkeeperError.new(custom_message)

      strategy = double(:strategy)
      request = double(token_request: strategy)
      allow(strategy).to receive(:authorize).and_raise(doorkeeper_error)
      allow(controller).to receive(:server).and_return(request)

      post :create

      expected_response_body = {
        "error" => custom_message,
        "error_description" => "Authorization custom message",
      }
      expect(response.status).to eq 400
      expect(response.headers["WWW-Authenticate"]).to match(/Bearer/)
      expect(JSON.parse(response.body)).to eq expected_response_body
    end
  end

  # http://tools.ietf.org/html/rfc7009#section-2.2
  describe "revoking tokens" do
    let(:client) { FactoryBot.create(:application) }
    let(:access_token) { FactoryBot.create(:access_token, application: client) }

    context "when associated app is public" do
      let(:client) { FactoryBot.create(:application, confidential: false) }

      it "returns 200" do
        post :revoke, params: { token: access_token.token }

        expect(response.status).to eq 200
      end

      it "revokes the access token" do
        post :revoke, params: { token: access_token.token }

        expect(access_token.reload).to have_attributes(revoked?: true)
      end
    end

    context "when associated app is confidential" do
      let(:client) { FactoryBot.create(:application, confidential: true) }
      let(:oauth_client) { Doorkeeper::OAuth::Client.new(client) }

      before(:each) do
        allow_any_instance_of(Doorkeeper::Server).to receive(:client) { oauth_client }
      end

      it "returns 200" do
        post :revoke, params: { token: access_token.token }

        expect(response.status).to eq 200
      end

      it "revokes the access token" do
        post :revoke, params: { token: access_token.token }

        expect(access_token.reload).to have_attributes(revoked?: true)
      end

      context "when authorization fails" do
        let(:some_other_client) { FactoryBot.create(:application, confidential: true) }
        let(:oauth_client) { Doorkeeper::OAuth::Client.new(some_other_client) }

        it "returns 200" do
          post :revoke, params: { token: access_token.token }

          expect(response.status).to eq 200
        end

        it "does not revoke the access token" do
          post :revoke, params: { token: access_token.token }

          expect(access_token.reload).to have_attributes(revoked?: false)
        end
      end
    end
  end

  describe "authorize response memoization" do
    it "memoizes the result of the authorization" do
      strategy = double(:strategy, authorize: true)
      expect(strategy).to receive(:authorize).once
      allow(controller).to receive(:strategy) { strategy }
      allow(controller).to receive(:create) do
        2.times { controller.send :authorize_response }
        controller.render json: {}, status: :ok
      end

      post :create
    end
  end

  describe "when requested token introspection" do
    let(:client) { FactoryBot.create(:application) }
    let(:access_token) { FactoryBot.create(:access_token, application: client) }
    let(:token_for_introspection) { FactoryBot.create(:access_token, application: client) }

    context "authorized using valid Bearer token" do
      it "responds with full token introspection" do
        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: token_for_introspection.token }

        should_have_json "active", true
        expect(json_response).to include("client_id", "token_type", "exp", "iat")
      end
    end

    context "authorized using valid Client Authentication" do
      it "responds with full token introspection" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: token_for_introspection.token }

        should_have_json "active", true
        expect(json_response).to include("client_id", "token_type", "exp", "iat")
        should_have_json "client_id", client.uid
      end
    end

    context "using custom introspection response" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          custom_introspection_response do |_token, _context|
            {
              sub: "Z5O3upPC88QrAjx00dis",
              aud: "https://protected.example.net/resource",
            }
          end
        end
      end

      it "responds with full token introspection" do
        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: token_for_introspection.token }

        expect(json_response).to include("client_id", "token_type", "exp", "iat", "sub", "aud")
        should_have_json "sub", "Z5O3upPC88QrAjx00dis"
        should_have_json "aud", "https://protected.example.net/resource"
      end
    end

    context "public access token" do
      let(:token_for_introspection) { FactoryBot.create(:access_token, application: nil) }

      it "responds with full token introspection" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: token_for_introspection.token }

        should_have_json "active", true
        expect(json_response).to include("client_id", "token_type", "exp", "iat")
        should_have_json "client_id", nil
      end
    end

    context "token was issued to a different client than is making this request" do
      let(:different_client) { FactoryBot.create(:application) }

      it "responds with only active state" do
        request.headers["Authorization"] = basic_auth_header_for_client(different_client)

        post :introspect, params: { token: token_for_introspection.token }

        expect(response).to be_successful

        should_have_json "active", false
        expect(json_response).not_to include("client_id", "token_type", "exp", "iat")
      end
    end

    context "authorized using invalid Bearer token" do
      let(:access_token) do
        FactoryBot.create(:access_token, application: client, revoked_at: 1.day.ago)
      end

      it "responds with invalid token error" do
        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: token_for_introspection.token }

        response_status_should_be 401

        should_not_have_json "active"
        should_have_json "error", "invalid_token"
      end
    end

    context "authorized using the Bearer token that need to be introspected" do
      it "responds with invalid token error" do
        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: access_token.token }

        response_status_should_be 401

        should_not_have_json "active"
        should_have_json "error", "invalid_token"
      end
    end

    context "using invalid credentials to authorize" do
      let(:client) { double(uid: "123123", secret: "666999") }
      let(:access_token) { FactoryBot.create(:access_token) }

      it "responds with invalid_client error" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: access_token.token }

        expect(response).not_to be_successful
        response_status_should_be 401

        should_not_have_json "active"
        should_have_json "error", "invalid_client"
      end
    end

    context "using wrong token value" do
      context "authorized using client credentials" do
        it "responds with only active state" do
          request.headers["Authorization"] = basic_auth_header_for_client(client)

          post :introspect, params: { token: SecureRandom.hex(16) }

          should_have_json "active", false
          expect(json_response).not_to include("client_id", "token_type", "exp", "iat")
        end
      end

      context "authorized using valid Bearer token" do
        it "responds with only active state" do
          request.headers["Authorization"] = "Bearer #{access_token.token}"

          post :introspect, params: { token: SecureRandom.hex(16) }

          should_have_json "active", false
          expect(json_response).not_to include("client_id", "token_type", "exp", "iat")
        end
      end
    end

    context "when requested access token expired" do
      let(:token_for_introspection) do
        FactoryBot.create(:access_token, application: client, created_at: 1.year.ago)
      end

      it "responds with only active state" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: token_for_introspection.token }

        should_have_json "active", false
        expect(json_response).not_to include("client_id", "token_type", "exp", "iat")
      end
    end

    context "when requested Access Token revoked" do
      let(:token_for_introspection) do
        FactoryBot.create(:access_token, application: client, revoked_at: 1.year.ago)
      end

      it "responds with only active state" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: token_for_introspection.token }

        should_have_json "active", false
        expect(json_response).not_to include("client_id", "token_type", "exp", "iat")
      end
    end

    context "unauthorized (no bearer token or client credentials)" do
      let(:token_for_introspection) { FactoryBot.create(:access_token) }

      it "responds with invalid_request error" do
        post :introspect, params: { token: token_for_introspection.token }

        expect(response).not_to be_successful
        response_status_should_be 400

        should_not_have_json "active"
        should_have_json "error", "invalid_request"
      end
    end
  end
end
