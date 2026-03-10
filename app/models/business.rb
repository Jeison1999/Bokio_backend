class Business < ApplicationRecord
  # Associations
  belongs_to :owner, class_name: 'User'
  has_one :subscription, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :tickets, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers and hyphens" }
  validates :phone, format: { with: /\A\d{10}\z/, message: "must be 10 digits" }, allow_blank: true

  # Callbacks
  before_validation :generate_slug, on: :create

  # Scopes
  scope :active, -> { where(active: true) }
  scope :with_valid_subscription, -> { joins(:subscription).where(subscriptions: { status: :active }).where('subscriptions.expires_at > ?', Time.current) }

  # Methods
  def subscription_valid?
    subscription.present? && subscription.active_and_valid?
  end

  def can_add_employee?
    return false unless subscription_valid?
    employees.count < subscription.max_employees
  end

  def suspend_for_non_payment!
    return unless subscription.present?
    subscription.update(status: :suspended)
    update(active: false)
  end

  def employees_limit_reached?
    return false unless subscription.present?
    employees.count >= subscription.max_employees
  end

  # ========================================
  # Validaciones de Horario
  # ========================================

  # ¿El negocio está abierto ahora mismo?
  def open_now?
    open_at?(Time.current)
  end

  # ¿El negocio está abierto en el momento indicado?
  def open_at?(time)
    return true if opening_time.nil? || closing_time.nil?

    current_time = time.seconds_since_midnight
    open  = opening_time.seconds_since_midnight
    close = closing_time.seconds_since_midnight

    # Verificar que está dentro del horario de apertura/cierre
    return false unless current_time >= open && current_time < close

    # Verificar que no está en horario de descanso
    if break_start_time.present? && break_end_time.present?
      break_start = break_start_time.seconds_since_midnight
      break_end   = break_end_time.seconds_since_midnight
      return false if current_time >= break_start && current_time < break_end
    end

    true
  end

  def closed_reason(time = Time.current)
    return nil if open_at?(time)
    return nil if opening_time.nil? || closing_time.nil?

    current_time = time.seconds_since_midnight
    open  = opening_time.seconds_since_midnight
    close = closing_time.seconds_since_midnight

    if current_time < open
      "Business not open yet. Opens at #{opening_time.strftime('%H:%M')}"
    elsif current_time >= close
      "Business is closed. Closes at #{closing_time.strftime('%H:%M')}"
    elsif break_start_time.present? && break_end_time.present?
      break_start = break_start_time.seconds_since_midnight
      break_end   = break_end_time.seconds_since_midnight
      if current_time >= break_start && current_time < break_end
        "Business is on break until #{break_end_time.strftime('%H:%M')}"
      end
    end
  end

  # ========================================
  # Métodos de Estadísticas
  # ========================================
  
  # Estadísticas generales
  def stats_summary(period = :today)
    tickets_scope = tickets_for_period(period)
    
    {
      total_tickets: tickets_scope.count,
      completed_tickets: tickets_scope.completed.count,
      paid_tickets: tickets_scope.paid_tickets.count,
      unpaid_tickets: tickets_scope.completed.unpaid_tickets.count,
      total_revenue: tickets_scope.paid_tickets.sum(:total_amount),
      pending_revenue: tickets_scope.completed.unpaid_tickets.sum(:total_amount),
      active_clients: tickets_scope.select(:client_id).distinct.count,
      average_ticket_value: average_ticket_value(tickets_scope)
    }
  end
  
  # Ingresos por período
  def revenue_by_period(period = :today)
    tickets_for_period(period).paid_tickets.sum(:total_amount)
  end
  
  # Estadísticas por empleado
  def stats_by_employee(period = :today)
    tickets_scope = tickets_for_period(period)
    
    employees.map do |employee|
      employee_tickets = tickets_scope.where(employee: employee)
      {
        employee_id: employee.id,
        employee_name: employee.name,
        total_tickets: employee_tickets.count,
        completed_tickets: employee_tickets.completed.count,
        revenue: employee_tickets.paid_tickets.sum(:total_amount),
        average_ticket_value: average_ticket_value(employee_tickets)
      }
    end.sort_by { |stat| -stat[:revenue] }
  end
  
  # Servicios más solicitados
  def top_services(period = :today, limit = 5)
    tickets_scope = tickets_for_period(period)
    ticket_ids = tickets_scope.pluck(:id)
    
    Service
      .joins('INNER JOIN ticket_services ON ticket_services.service_id = services.id')
      .where(ticket_services: { ticket_id: ticket_ids })
      .group('services.id')
      .select('services.id, services.name, services.price, COUNT(ticket_services.id) as service_count, SUM(services.price) as total_revenue')
      .order('service_count DESC')
      .limit(limit)
      .map do |service|
        {
          service_id: service.id,
          service_name: service.name,
          service_price: service.price,
          times_requested: service.service_count,
          total_revenue: service.total_revenue
        }
      end
  end
  
  # Datos para gráficas diarias (últimos 7 días)
  def daily_revenue_chart(days = 7)
    (0...days).map do |i|
      date = i.days.ago.to_date
      {
        date: date.strftime('%Y-%m-%d'),
        revenue: tickets.where('DATE(tickets.created_at) = ?', date).paid_tickets.sum(:total_amount),
        tickets_count: tickets.where('DATE(tickets.created_at) = ?', date).completed.count
      }
    end.reverse
  end
  
  # Obtener tickets según período (público para uso en controladores)
  def tickets_for_period(period)
    case period.to_sym
    when :today
      tickets.today
    when :week
      tickets.this_week
    when :month
      tickets.this_month
    when :year
      tickets.this_year
    else
      tickets.today
    end
  end

  private
  
  def average_ticket_value(tickets_scope)
    count = tickets_scope.count
    return 0 if count.zero?
    
    (tickets_scope.sum(:total_amount) / count).round(2)
  end

  def generate_slug
    return if slug.present?
    base_slug = name.parameterize
    self.slug = base_slug
    counter = 1
    while Business.exists?(slug: self.slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
