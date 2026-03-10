class TicketService < ApplicationRecord
  belongs_to :ticket
  belongs_to :service
  
  validates :ticket_id, uniqueness: { scope: :service_id }
end
