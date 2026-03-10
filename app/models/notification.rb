class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :ticket
  
  # Tipos de notificaciones
  enum :notification_type, {
    next_in_queue: 0,      # Cliente es el próximo en la fila
    one_away: 1,           # Falta 1 cliente antes del tuyo
    ticket_ready: 2,       # Tu ticket está listo para ser atendido
    ticket_completed: 3,   # Tu ticket fue completado
    ticket_cancelled: 4    # Tu ticket fue cancelado
  }
  
  validates :notification_type, presence: true
  validates :message, presence: true
  
  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  
  # Marcar como leída
  def mark_as_read!
    update(read: true)
  end
  
  # Enviar notificación por WebSocket
  def broadcast
    ActionCable.server.broadcast(
      "notifications_user_#{user_id}",
      {
        action: 'notification_created',
        notification: {
          id: id,
          type: notification_type,
          message: message,
          ticket_id: ticket_id,
          ticket_number: ticket.ticket_number,
          read: read,
          sent_at: sent_at || created_at,
          created_at: created_at
        }
      }
    )
    
    update(sent_at: Time.current) unless sent_at
  end
end
