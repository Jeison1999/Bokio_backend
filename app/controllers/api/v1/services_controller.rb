module Api
  module V1
    class ServicesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_business
      before_action -> { ensure_valid_subscription(@business) }, except: [:index, :show]
      before_action :set_service, only: [:show, :update, :destroy]

      # GET /api/v1/businesses/:business_id/services
      def index
        services = policy_scope(@business.services).includes(:employees)
        render json: services.map { |s| ServiceSerializer.new(s).serializable_hash }, status: :ok
      end

      # GET /api/v1/businesses/:business_id/services/:id
      def show
        authorize @service
        render json: ServiceSerializer.new(@service).serializable_hash, status: :ok
      end

      # POST /api/v1/businesses/:business_id/services
      def create
        service = @business.services.build(service_params)
        authorize service
        
        if service.save
          render json: ServiceSerializer.new(service).serializable_hash, status: :created
        else
          render json: { errors: service.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/businesses/:business_id/services/:id
      def update
        authorize @service
        if @service.update(service_params)
          render json: ServiceSerializer.new(@service).serializable_hash, status: :ok
        else
          render json: { errors: @service.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/businesses/:business_id/services/:id
      def destroy
        authorize @service
        @service.destroy
        head :no_content
      end

      private

      def set_business
        @business = Business.find(params[:business_id])
      end

      def set_service
        @service = @business.services.find(params[:id])
      end

      def service_params
        params.require(:service).permit(:name, :description, :price, :duration, :active)
      end
    end
  end
end
