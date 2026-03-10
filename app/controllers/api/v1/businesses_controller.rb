module Api
  module V1
    class BusinessesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_business, only: [:show, :update, :destroy]

      # GET /api/v1/businesses
      def index
        @businesses = policy_scope(Business).active.includes(:owner, :subscription, :services)

        # Clientes solo ven negocios con suscripción activa y válida
        if current_user.client?
          @businesses = @businesses.with_valid_subscription
        end

        # Búsqueda por nombre o descripción (ILIKE = case-insensitive en PostgreSQL)
        if params[:q].present?
          query = "%#{params[:q].strip}%"
          @businesses = @businesses.where('businesses.name ILIKE ? OR businesses.description ILIKE ?', query, query)
        end

        render json: @businesses, include: [:owner, :subscription], status: :ok
      end

      # GET /api/v1/businesses/by_slug/:slug
      def by_slug
        @business = Business.active.find_by!(slug: params[:slug])

        # Clientes solo ven negocios con suscripción válida
        if current_user.client? && !@business.subscription_valid?
          render json: { error: 'Business not available' }, status: :not_found and return
        end

        render json: business_public_view(@business), status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Business not found' }, status: :not_found
      end

      # GET /api/v1/businesses/:id
      def show
        authorize @business
        # Para clientes, devolver vista pública con empleados y servicios
        if current_user.client?
          render json: business_public_view(@business), status: :ok
        else
          render json: @business, include: [:owner, :subscription], status: :ok
        end
      end

      # POST /api/v1/businesses
      def create
        @business = current_user.businesses.build(business_params)
        authorize @business
        
        if @business.save
          # Crear suscripción básica por defecto
          @business.create_subscription!(
            plan: :basic,
            started_at: Time.current,
            expires_at: 1.month.from_now
          )
          
          render json: @business, include: [:subscription], status: :created
        else
          render json: { errors: @business.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/businesses/:id
      def update
        authorize @business
        if @business.update(business_params)
          render json: @business, include: [:subscription], status: :ok
        else
          render json: { errors: @business.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/businesses/:id
      def destroy
        authorize @business
        @business.destroy
        head :no_content
      end

      private

      def set_business
        @business = Business.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Business not found' }, status: :not_found
      end

      def business_params
        params.require(:business).permit(
          :name, :description, :address, :phone, :logo_url,
          :opening_time, :closing_time, :break_start_time, :break_end_time, :active
        )
      end

      # Vista pública del negocio para clientes: incluye empleados disponibles y servicios activos
      def business_public_view(business)
        {
          id: business.id,
          name: business.name,
          description: business.description,
          slug: business.slug,
          address: business.address,
          phone: business.phone,
          logo_url: business.logo_url,
          opening_time: business.opening_time,
          closing_time: business.closing_time,
          break_start_time: business.break_start_time,
          break_end_time: business.break_end_time,
          employees: business.employees.includes(:services).map do |emp|
            {
              id: emp.id,
              name: emp.name,
              avatar_url: emp.avatar_url,
              status: emp.status,
              services: emp.services.where(active: true).map do |svc|
                { id: svc.id, name: svc.name, price: svc.price, duration: svc.duration }
              end
            }
          end,
          services: business.services.where(active: true).map do |svc|
            { id: svc.id, name: svc.name, description: svc.description, price: svc.price, duration: svc.duration }
          end,
          current_queue_size: business.tickets.active.count
        }
      end
    end
  end
end
