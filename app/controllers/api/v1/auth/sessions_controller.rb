module Api
  module V1
    module Auth
      class SessionsController < ApplicationController
        def create
          user = User.find_by(email: params[:user][:email])
          
          if user&.valid_password?(params[:user][:password])
            token = generate_jwt_token(user)
            render json: {
              message: 'Logged in successfully.',
              token: token,
              data: UserSerializer.new(user).serializable_hash[:data][:attributes]
            }, status: :ok
          else
            render json: {
              message: 'Invalid email or password.'
            }, status: :unauthorized
          end
        end

        def destroy
          # JWT is stateless - tokens are valid until expiration
          # Client should discard the token
          render json: {
            message: 'Logged out successfully.'
          }, status: :ok
        end

        private

        def generate_jwt_token(user)
          JWT.encode(
            { user_id: user.id, exp: 24.hours.from_now.to_i },
            ENV['DEVISE_JWT_SECRET_KEY'] || Rails.application.credentials.devise_jwt_secret_key
          )
        end
      end
    end
  end
end
