module Api
  module V1
    module Auth
      class RegistrationsController < ApplicationController
        def create
          user = User.new(user_params)
          
          if user.save
            token = generate_jwt_token(user)
            render json: {
              message: 'Signed up successfully.',
              token: token,
              data: UserSerializer.new(user).serializable_hash[:data][:attributes]
            }, status: :created
          else
            render json: {
              message: 'User could not be created.',
              errors: user.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        private

        def user_params
          params.require(:user).permit(:email, :password, :password_confirmation, :name, :phone, :role)
        end

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
