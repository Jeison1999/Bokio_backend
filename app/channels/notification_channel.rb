class NotificationChannel < ApplicationCable::Channel
  def subscribed
    # Cada usuario se suscribe a su propio canal de notificaciones
    stream_from "notifications_user_#{current_user.id}"
    Rails.logger.info "User #{current_user.id} subscribed to notifications"
  end

  def unsubscribed
    # Cleanup cuando se desuscribe
    Rails.logger.info "User #{current_user.id} unsubscribed from notifications"
  end
  
  # Cliente puede marcar notificación como leída desde el canal
  def mark_as_read(data)
    notification = Notification.find_by(id: data['notification_id'], user_id: current_user.id)
    notification&.mark_as_read!
  rescue StandardError => e
    Rails.logger.error "Error marking notification as read: #{e.message}"
  end
end
