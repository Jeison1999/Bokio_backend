class Api::V1::Admin::StatsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_super_admin
  
  # GET /api/v1/admin/stats/overview
  def overview
    period = params[:period] || :today
    
    render json: {
      period: period,
      platform_stats: platform_stats(period),
      businesses: {
        total: Business.count,
        active: Business.active.count,
        with_valid_subscription: Business.with_valid_subscription.count,
        suspended: Business.where(active: false).count
      },
      subscriptions: subscription_stats,
      top_businesses: top_businesses_by_revenue(period, 10)
    }
  end
  
  # GET /api/v1/admin/stats/businesses
  def businesses
    period = params[:period] || :month
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    
    businesses = Business.includes(:subscription, :owner)
                        .order(created_at: :desc)
                        .page(page)
                        .per(per_page)
    
    render json: {
      businesses: businesses.map do |business|
        {
          id: business.id,
          name: business.name,
          owner: business.owner.name,
          subscription_plan: business.subscription&.plan,
          subscription_status: business.subscription&.status,
          active: business.active,
          stats: business.stats_summary(period),
          created_at: business.created_at
        }
      end,
      pagination: {
        current_page: businesses.current_page,
        total_pages: businesses.total_pages,
        total_count: Business.count
      }
    }
  end
  
  # GET /api/v1/admin/stats/revenue
  def revenue
    period = params[:period] || :month
    
    render json: {
      period: period,
      total_platform_revenue: total_platform_revenue(period),
      revenue_by_business: revenue_by_business(period),
      subscription_revenue: subscription_revenue,
      daily_revenue_chart: daily_platform_revenue_chart(30)
    }
  end
  
  # GET /api/v1/admin/stats/subscriptions
  def subscriptions
    render json: {
      by_plan: Subscription.group(:plan).count,
      by_status: Subscription.group(:status).count,
      expiring_soon: expiring_soon_subscriptions,
      total_active: Subscription.active.count,
      total_suspended: Subscription.suspended.count,
      monthly_recurring_revenue: calculate_mrr
    }
  end
  
  private
  
  def authorize_super_admin
    unless current_user.super_admin?
      render json: { error: 'Unauthorized. Super admin access required.' }, status: :forbidden
    end
  end
  
  def platform_stats(period)
    all_tickets = Ticket.includes(:business)
    tickets_scope = case period.to_sym
                    when :today then all_tickets.today
                    when :week then all_tickets.this_week
                    when :month then all_tickets.this_month
                    when :year then all_tickets.this_year
                    else all_tickets.today
                    end
    
    {
      total_tickets: tickets_scope.count,
      completed_tickets: tickets_scope.completed.count,
      active_tickets: tickets_scope.active.count,
      total_revenue: tickets_scope.paid_tickets.sum(:total_amount),
      pending_revenue: tickets_scope.completed.unpaid_tickets.sum(:total_amount),
      unique_clients: tickets_scope.select(:client_id).distinct.count,
      average_ticket_value: tickets_scope.count.zero? ? 0 : (tickets_scope.sum(:total_amount) / tickets_scope.count).round(2)
    }
  end
  
  def subscription_stats
    {
      total: Subscription.count,
      active: Subscription.active.count,
      suspended: Subscription.suspended.count,
      by_plan: {
        basic: Subscription.basic.count,
        pro: Subscription.pro.count,
        premium: Subscription.premium.count
      }
    }
  end
  
  def top_businesses_by_revenue(period, limit)
    Business.includes(:subscription, :owner).map do |business|
      revenue = business.revenue_by_period(period)
      {
        id: business.id,
        name: business.name,
        owner: business.owner.name,
        plan: business.subscription&.plan,
        revenue: revenue,
        tickets_count: business.tickets_for_period(period).completed.count
      }
    end.sort_by { |b| -b[:revenue] }.take(limit)
  end
  
  def total_platform_revenue(period)
    all_tickets = case period.to_sym
                  when :today then Ticket.today
                  when :week then Ticket.this_week
                  when :month then Ticket.this_month
                  when :year then Ticket.this_year
                  else Ticket.today
                  end
    
    all_tickets.paid_tickets.sum(:total_amount)
  end
  
  def revenue_by_business(period)
    Business.includes(:tickets).map do |business|
      {
        business_id: business.id,
        business_name: business.name,
        revenue: business.revenue_by_period(period)
      }
    end.sort_by { |b| -b[:revenue] }.take(20)
  end
  
  def subscription_revenue
    {
      basic: Subscription.active.basic.count * 25000,
      pro: Subscription.active.pro.count * 45000,
      premium: Subscription.active.premium.count * 70000,
      total: (Subscription.active.basic.count * 25000) + 
             (Subscription.active.pro.count * 45000) + 
             (Subscription.active.premium.count * 70000)
    }
  end
  
  def expiring_soon_subscriptions
    Subscription.where('expires_at BETWEEN ? AND ?', Time.current, 7.days.from_now)
                .includes(business: :owner)
                .map do |sub|
      {
        business_id: sub.business.id,
        business_name: sub.business.name,
        owner_email: sub.business.owner.email,
        plan: sub.plan,
        expires_at: sub.expires_at
      }
    end
  end
  
  def daily_platform_revenue_chart(days)
    (0...days).map do |i|
      date = i.days.ago.to_date
      {
        date: date.strftime('%Y-%m-%d'),
        revenue: Ticket.where('DATE(created_at) = ?', date).paid_tickets.sum(:total_amount),
        tickets: Ticket.where('DATE(created_at) = ?', date).completed.count
      }
    end.reverse
  end
  
  def calculate_mrr
    # Monthly Recurring Revenue de suscripciones
    (Subscription.active.basic.count * 25000) + 
    (Subscription.active.pro.count * 45000) + 
    (Subscription.active.premium.count * 70000)
  end
end
