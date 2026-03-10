class ApplicationController < ActionController::API
  include Pundit::Authorization
  
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Manejo de errores de autorización
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :phone, :role])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :phone, :avatar_url])
  end

  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless token

    begin
      decoded = JWT.decode(
        token,
        ENV['DEVISE_JWT_SECRET_KEY'] || Rails.application.credentials.devise_jwt_secret_key
      )
      @current_user = User.find(decoded[0]['user_id'])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  # Verificar que el negocio tenga suscripción activa
  def ensure_valid_subscription(business)
    return if current_user&.super_admin?
    
    unless business.subscription_valid?
      render json: { 
        error: 'Subscription Required', 
        message: 'This business does not have an active subscription. Please renew your subscription to continue.' 
      }, status: :payment_required
      return false
    end
    true
  end

  private

  def user_not_authorized
    render json: { 
      error: 'Unauthorized', 
      message: 'You are not authorized to perform this action.' 
    }, status: :forbidden
  end
end
