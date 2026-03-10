class Ticket < ApplicationRecord
  belongs_to :business
  belongs_to :client, class_name: 'User'
  belongs_to :employee, optional: true
  
  has_many :ticket_services, dependent: :destroy
  has_many :services, through: :ticket_services
  has_many :notifications, dependent: :destroy
  
  enum :status, { waiting: 0, in_progress: 1, completed: 2, cancelled: 3, no_show: 4 }
  
  validates :ticket_number, presence: true, uniqueness: { scope: :business_id }
  validates :status, presence: true
  
  before_validation :generate_ticket_number, on: :create
  before_create :set_queue_position
  before_create :calculate_total_amount
  after_create :calculate_estimated_time
  after_create :broadcast_ticket_created
  after_update :broadcast_ticket_updated
  after_update :check_and_notify_next_clients
  after_destroy :broadcast_ticket_destroyed
  
  scope :active, -> { where(status: [:waiting, :in_progress]) }
  scope :finished, -> { where(status: [:completed, :cancelled, :no_show]) }
  scope :by_business, ->(business_id) { where(business_id: business_id) }
  scope :ordered_by_queue, -> { order(queue_position: :asc) }
  scope :paid_tickets, -> { where(paid: true) }
  scope :unpaid_tickets, -> { where(paid: false) }
  scope :today, -> { where('tickets.created_at >= ?', Time.current.beginning_of_day) }
  scope :this_week, -> { where('tickets.created_at >= ?', Time.current.beginning_of_week) }
  scope :this_month, -> { where('tickets.created_at >= ?', Time.current.beginning_of_month) }
  scope :this_year, -> { where('tickets.created_at >= ?', Time.current.beginning_of_year) }
  scope :date_range, ->(start_date, end_date) { where(tickets: { created_at: start_date..end_date }) }
  
  # Marcar como pagado
  def mark_as_paid!
    update(paid: true)
  end
  
  private
  
  def generate_ticket_number
    return if ticket_number.present?
    date_prefix = Time.current.strftime('%Y%m%d')
    last_ticket = business.tickets.where('ticket_number LIKE ?', "#{date_prefix}%").order(ticket_number: :desc).first
    
    if last_ticket
      sequence = last_ticket.ticket_number.split('-').last.to_i + 1
    else
      sequence = 1
    end
    
    self.ticket_number = "#{date_prefix}-#{sequence.to_s.rjust(4, '0')}"
  end
  
  def set_queue_position
    max_position = business.tickets.active.maximum(:queue_position) || 0
    self.queue_position = max_position + 1
  end
  
  def calculate_estimated_time
    return unless services.any?
    self.estimated_time = services.sum(:duration)
    save
  end
  
  def calculate_total_amount
    if services.loaded?
      self.total_amount = services.sum(&:price)
    else
      self.total_amount = services.sum(:price)
    end
  end
  
  def broadcast_ticket_created
    broadcast_queue_update('ticket_created')
  end
  
  def broadcast_ticket_updated
    broadcast_queue_update('ticket_updated') if saved_change_to_status? || saved_change_to_queue_position?
  end
  
  def broadcast_ticket_destroyed
    broadcast_queue_update('ticket_destroyed')
  end
  
  # Notificar a clientes cuando están a 1 turno de ser atendidos
  def check_and_notify_next_clients
    # Solo notificar cuando un ticket se COMPLETA (la cola avanza realmente)
    return unless saved_change_to_status? && completed?
    
    # Obtener tickets activos ordenados por queue_position
    waiting_tickets = business.tickets.waiting.ordered_by_queue.limit(2)
    
    # Si hay al menos 1 ticket esperando
    if waiting_tickets.any?
      first_waiting = waiting_tickets.first
      
      # Notificar al primer cliente en espera que es el siguiente
      notify_client(
        first_waiting,
        :next_in_queue,
        "¡Es tu turno! Estás a punto de ser atendido."
      )
      
      # Si hay un segundo cliente, notificar que falta 1 turno
      if waiting_tickets.size > 1
        second_waiting = waiting_tickets.second
        notify_client(
          second_waiting,
          :one_away,
          "¡Tu turno está cerca! Falta 1 cliente antes que tú. Ticket actual: #{first_waiting.ticket_number}"
        )
      end
    end
  end
  
  # Crear y enviar notificación a un cliente
  def notify_client(ticket, notification_type, message)
    # Evitar duplicar notificaciones del mismo tipo para el mismo ticket
    existing = ticket.notifications.where(
      notification_type: notification_type,
      created_at: 5.minutes.ago..Time.current
    ).first
    
    return if existing
    
    notification = ticket.notifications.create!(
      user: ticket.client,
      notification_type: notification_type,
      message: message
    )
    
    # Enviar por WebSocket
    notification.broadcast
  rescue StandardError => e
    Rails.logger.error "Error creating notification: #{e.message}"
  end
  
  def broadcast_queue_update(action)
    ActionCable.server.broadcast(
      "queue_business_#{business_id}",
      {
        action: action,
        ticket: TicketSerializer.new(self).serializable_hash,
        queue: fetch_current_queue
      }
    )
  end
  
  def fetch_current_queue
    business.tickets.active.includes(:client, :employee, :services).ordered_by_queue.map do |ticket|
      TicketSerializer.new(ticket).serializable_hash
    end
  end
end
