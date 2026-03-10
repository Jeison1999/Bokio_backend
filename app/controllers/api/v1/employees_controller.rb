module Api
  module V1
    class EmployeesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_business
      before_action -> { ensure_valid_subscription(@business) }, except: [:index, :show]
      before_action :set_employee, only: [:show, :update, :destroy, :assign_services]

      # GET /api/v1/businesses/:business_id/employees
      def index
        employees = policy_scope(@business.employees).includes(:user, :services)
        render json: employees.map { |e| EmployeeSerializer.new(e).serializable_hash }, status: :ok
      end

      # GET /api/v1/businesses/:business_id/employees/:id
      def show
        authorize @employee
        render json: EmployeeSerializer.new(@employee).serializable_hash, status: :ok
      end

      # POST /api/v1/businesses/:business_id/employees
      def create
        employee = @business.employees.build(employee_params)
        authorize employee
        
        if employee.save
          render json: EmployeeSerializer.new(employee).serializable_hash, status: :created
        else
          render json: { errors: employee.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/businesses/:business_id/employees/:id
      def update
        authorize @employee
        if @employee.update(employee_params)
          render json: EmployeeSerializer.new(@employee).serializable_hash, status: :ok
        else
          render json: { errors: @employee.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/businesses/:business_id/employees/:id
      def destroy
        authorize @employee
        @employee.destroy
        head :no_content
      end

      # POST /api/v1/businesses/:business_id/employees/:id/assign_services
      def assign_services
        authorize @employee, :assign_services?
        service_ids = params[:service_ids] || []
        
        @employee.service_ids = service_ids
        
        render json: EmployeeSerializer.new(@employee).serializable_hash, status: :ok
      end

      private

      def set_business
        @business = Business.find(params[:business_id])
      end

      def set_employee
        @employee = @business.employees.find(params[:id])
      end

      def employee_params
        params.require(:employee).permit(:name, :email, :phone, :avatar_url, :status, :user_id, service_ids: [])
      end
    end
  end
end
