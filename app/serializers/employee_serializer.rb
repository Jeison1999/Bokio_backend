class EmployeeSerializer
  include JSONAPI::Serializer
  
  attributes :id, :business_id, :name, :email, :phone, :avatar_url, :status, :created_at, :updated_at
  
  attribute :user do |employee|
    if employee.user
      {
        id: employee.user.id,
        email: employee.user.email,
        name: employee.user.name,
        phone: employee.user.phone,
        avatar_url: employee.user.avatar_url,
        role: employee.user.role
      }
    end
  end
  
  attribute :services do |employee|
    employee.services.map do |service|
      {
        id: service.id,
        name: service.name,
        description: service.description,
        price: service.price.to_s,
        duration: service.duration,
        active: service.active
      }
    end
  end
end
