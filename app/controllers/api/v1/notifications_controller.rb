class Api::V1::NotificationsController < ApplicationController
  before_action :authenticate_user!
  
  # GET /api/v1/notifications
  def index
    notifications = current_user.notifications
                                .includes(:ticket)
                                .recent
                                .limit(50)
    
    render json: notifications.map { |n| notification_json(n) }
  end
  
  # GET /api/v1/notifications/unread
  def unread
    notifications = current_user.notifications
                                .unread
                                .includes(:ticket)
                                .recent
                                .limit(20)
    
    render json: {
      count: notifications.size,
      notifications: notifications.map { |n| notification_json(n) }
    }
  end
  
  # PATCH /api/v1/notifications/:id/mark_as_read
  def mark_as_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_as_read!
    
    render json: { message: 'Notification marked as read' }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Notification not found' }, status: :not_found
  end
  
  # POST /api/v1/notifications/mark_all_as_read
  def mark_all_as_read
    current_user.notifications.unread.update_all(read: true)
    
    render json: { message: 'All notifications marked as read' }
  end
  
  private
  
  def notification_json(notification)
    {
      id: notification.id,
      type: notification.notification_type,
      message: notification.message,
      read: notification.read,
      ticket: {
        id: notification.ticket.id,
        ticket_number: notification.ticket.ticket_number,
        status: notification.ticket.status
      },
      sent_at: notification.sent_at || notification.created_at,
      created_at: notification.created_at
    }
  end
end
