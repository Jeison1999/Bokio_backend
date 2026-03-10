class TicketSerializer
  include JSONAPI::Serializer
  
  attributes :id, :business_id, :ticket_number, :status, :queue_position, 
             :estimated_time, :started_at, :completed_at, :created_at, :updated_at
  
  attribute :client do |ticket|
    {
      id: ticket.client.id,
      name: ticket.client.name,
      email: ticket.client.email,
      phone: ticket.client.phone
    }
  end
  
  attribute :employee do |ticket|
    if ticket.employee
      {
        id: ticket.employee.id,
        name: ticket.employee.name,
        email: ticket.employee.email,
        phone: ticket.employee.phone,
        status: ticket.employee.status
      }
    end
  end
  
  attribute :services do |ticket|
    ticket.services.map do |service|
      {
        id: service.id,
        name: service.name,
        description: service.description,
        price: service.price.to_s,
        duration: service.duration
      }
    end
  end
  
  attribute :total_price do |ticket|
    ticket.services.sum(:price).to_s
  end
end
