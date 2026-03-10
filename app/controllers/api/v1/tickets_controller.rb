module Api
  module V1
    class TicketsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_business
      before_action -> { ensure_valid_subscription(@business) }, only: [:create, :update, :start, :complete]
      before_action :set_ticket, only: [:show, :update, :destroy, :start, :complete, :cancel, :no_show, :mark_as_paid]

      # GET /api/v1/businesses/:business_id/tickets
      def index
        tickets = policy_scope(@business.tickets).includes(:client, :employee, :services).ordered_by_queue
        
        # Filtrar por status si se proporciona
        tickets = tickets.where(status: params[:status]) if params[:status].present?
        
        render json: tickets.map { |t| TicketSerializer.new(t).serializable_hash }, status: :ok
      end

      # GET /api/v1/businesses/:business_id/tickets/:id
      def show
        authorize @ticket
        render json: TicketSerializer.new(@ticket).serializable_hash, status: :ok
      end

      # POST /api/v1/businesses/:business_id/tickets
      def create
        # Validar horario del negocio antes de crear el ticket
        unless @business.open_now?
          reason = @business.closed_reason || 'Business is currently closed'
          return render json: { error: reason }, status: :unprocessable_entity
        end

        ticket_attributes = params[:ticket].present? ? ticket_params : {}
        ticket = @business.tickets.build(ticket_attributes)
        ticket.client = current_user
        authorize ticket
        
        if ticket.save
          # Asignar servicios si se proporcionan
          ticket.service_ids = params[:service_ids] if params[:service_ids].present?
          ticket.reload
          
          render json: TicketSerializer.new(ticket).serializable_hash, status: :created
        else
          render json: { errors: ticket.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/businesses/:business_id/tickets/:id
      def update
        authorize @ticket
        
        if @ticket.update(ticket_params)
          render json: TicketSerializer.new(@ticket).serializable_hash, status: :ok
        else
          render json: { errors: @ticket.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/businesses/:business_id/tickets/:id
      def destroy
        authorize @ticket
        
        @ticket.destroy
        head :no_content
      end

      # POST /api/v1/businesses/:business_id/tickets/:id/start
      def start
        authorize @ticket, :start?
        
        if @ticket.waiting?
          @ticket.update(
            status: :in_progress,
            started_at: Time.current,
            employee_id: params[:employee_id] || @ticket.employee_id
          )
          render json: TicketSerializer.new(@ticket).serializable_hash, status: :ok
        else
          render json: { error: 'Ticket cannot be started' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/businesses/:business_id/tickets/:id/complete
      def complete
        authorize @ticket, :complete?
        
        if @ticket.in_progress?
          @ticket.update(
            status: :completed,
            completed_at: Time.current
          )
          render json: TicketSerializer.new(@ticket).serializable_hash, status: :ok
        else
          render json: { error: 'Ticket cannot be completed' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/businesses/:business_id/tickets/:id/cancel
      def cancel
        authorize @ticket, :cancel?
        
        @ticket.update(status: :cancelled)
        render json: TicketSerializer.new(@ticket).serializable_hash, status: :ok
      end
      
      # POST /api/v1/businesses/:business_id/tickets/:id/no_show
      def no_show
        authorize @ticket, :no_show?
        
        if @ticket.waiting?
          @ticket.update(status: :no_show)
          render json: TicketSerializer.new(@ticket).serializable_hash, status: :ok
        else
          render json: { error: 'Only waiting tickets can be marked as no_show' }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/businesses/:business_id/tickets/:id/mark_as_paid
      def mark_as_paid
        authorize @ticket, :update?
        
        if @ticket.completed? && !@ticket.paid
          @ticket.mark_as_paid!
          render json: TicketSerializer.new(@ticket).serializable_hash, status: :ok
        else
          error_msg = @ticket.paid ? 'Ticket already paid' : 'Only completed tickets can be marked as paid'
          render json: { error: error_msg }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/businesses/:business_id/tickets/queue
      def queue
        tickets = policy_scope(@business.tickets).active.includes(:client, :employee, :services).ordered_by_queue
        render json: tickets.map { |t| TicketSerializer.new(t).serializable_hash }, status: :ok
      end

      private

      def set_business
        @business = Business.find(params[:business_id])
      end

      def set_ticket
        @ticket = @business.tickets.find(params[:id])
      end

      def ticket_params
        params.require(:ticket).permit(:employee_id, :status, service_ids: [])
      end
    end
  end
end
