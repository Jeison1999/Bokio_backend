class QueueChannel < ApplicationCable::Channel
  def subscribed
    # Client must provide business_id when subscribing
    business_id = params[:business_id]
    
    if business_id
      stream_from "queue_business_#{business_id}"
      Rails.logger.info "User #{current_user.id} subscribed to queue_business_#{business_id}"
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    Rails.logger.info "User #{current_user.id} unsubscribed from queue"
  end
end
