class BusinessSerializer
  include JSONAPI::Serializer
  
  attributes :id, :name, :description, :slug, :address, :phone, :logo_url,
             :opening_time, :closing_time, :break_start_time, :break_end_time,
             :active, :created_at
  
  belongs_to :owner, serializer: UserSerializer
  has_one :subscription
end
