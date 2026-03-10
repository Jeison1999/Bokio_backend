class SubscriptionSerializer
  include JSONAPI::Serializer
  
  attributes :id, :plan, :price, :max_employees, :status, 
             :started_at, :expires_at, :created_at
  
  attribute :is_expired do |subscription|
    subscription.expired?
  end
  
  attribute :is_active_and_valid do |subscription|
    subscription.active_and_valid?
  end
end
