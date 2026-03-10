class UserSerializer
  include JSONAPI::Serializer
  
  attributes :id, :email, :name, :phone, :avatar_url, :role, :created_at
end
