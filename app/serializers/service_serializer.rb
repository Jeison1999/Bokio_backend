class ServiceSerializer
  include JSONAPI::Serializer
  
  attributes :id, :business_id, :name, :description, :duration, :active, :created_at, :updated_at
  
  attribute :price do |service|
    service.price.to_s
  end
  
  attribute :employees do |service|
    service.employees.map do |employee|
      {
        id: employee.id,
        name: employee.name,
        email: employee.email,
        phone: employee.phone,
        status: employee.status
      }
    end
  end
end
