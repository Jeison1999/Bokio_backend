class Api::V1::StatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_business
  before_action :authorize_business_access
  
  # GET /api/v1/businesses/:business_id/stats
  def index
    period = params[:period] || :today
    
    render json: {
      business: {
        id: @business.id,
        name: @business.name
      },
      period: period,
      summary: @business.stats_summary(period),
      by_employee: @business.stats_by_employee(period),
      top_services: @business.top_services(period, 5)
    }
  end
  
  # GET /api/v1/businesses/:business_id/stats/dashboard
  def dashboard
    render json: {
      today: @business.stats_summary(:today),
      week: @business.stats_summary(:week),
      month: @business.stats_summary(:month),
      daily_chart: @business.daily_revenue_chart(7),
      top_employees: @business.stats_by_employee(:month).take(5),
      top_services: @business.top_services(:month, 10)
    }
  end
  
  # GET /api/v1/businesses/:business_id/stats/revenue
  def revenue
    period = params[:period] || :today
    
    render json: {
      period: period,
      total_revenue: @business.revenue_by_period(period),
      paid_tickets: @business.tickets_for_period(period).paid_tickets.count,
      pending_revenue: @business.tickets_for_period(period).completed.unpaid_tickets.sum(:total_amount),
      pending_tickets: @business.tickets_for_period(period).completed.unpaid_tickets.count
    }
  end
  
  # GET /api/v1/businesses/:business_id/stats/employees/:employee_id
  def employee_stats
    employee = @business.employees.find(params[:employee_id])
    period = params[:period] || :today
    tickets_scope = @business.tickets_for_period(period).where(employee: employee)
    
    render json: {
      employee: {
        id: employee.id,
        name: employee.name,
        email: employee.email
      },
      period: period,
      total_tickets: tickets_scope.count,
      completed_tickets: tickets_scope.completed.count,
      in_progress: tickets_scope.in_progress.count,
      waiting: tickets_scope.waiting.count,
      revenue: tickets_scope.paid_tickets.sum(:total_amount),
      average_ticket_value: tickets_scope.count.zero? ? 0 : (tickets_scope.sum(:total_amount) / tickets_scope.count).round(2),
      services_provided: service_breakdown(tickets_scope)
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Employee not found' }, status: :not_found
  end
  
  private
  
  def set_business
    @business = Business.find(params[:business_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Business not found' }, status: :not_found
  end
  
  def authorize_business_access
    # Super admin puede ver estadísticas de cualquier negocio
    return if current_user.super_admin?
    
    # Admin/Employee solo puede ver estadísticas de su propio negocio
    unless current_user.businesses.include?(@business) || 
           @business.employees.exists?(user_id: current_user.id)
      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end
  
  def service_breakdown(tickets_scope)
    Service
      .joins(ticket_services: :ticket)
      .where(tickets: { id: tickets_scope.pluck(:id) })
      .group('services.id')
      .select('services.id, services.name, COUNT(ticket_services.id) as count')
      .order('count DESC')
      .map { |s| { service_name: s.name, times_provided: s.count } }
  end
end
