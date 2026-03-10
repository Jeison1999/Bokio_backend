# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# Clear existing data
puts "Cleaning existing data..."
User.destroy_all

# Create Super Admin
puts "Creating Super Admin..."
super_admin = User.create!(
  email: "superadmin@bokio.com",
  password: "password123",
  password_confirmation: "password123",
  name: "Super Admin Bokio",
  phone: "1234567890",
  role: :super_admin
)
puts "✅ Super Admin created: #{super_admin.email}"

# Create Admin (Business Owner)
puts "Creating Admin (Business Owner)..."
admin = User.create!(
  email: "admin@barberia.com",
  password: "password123",
  password_confirmation: "password123",
  name: "Juan Pérez",
  phone: "3001234567",
  role: :admin
)
puts "✅ Admin created: #{admin.email}"

# Create Employee
puts "Creating Employee..."
employee = User.create!(
  email: "empleado@barberia.com",
  password: "password123",
  password_confirmation: "password123",
  name: "Carlos Gómez",
  phone: "3109876543",
  role: :employee
)
puts "✅ Employee created: #{employee.email}"

# Create Client
puts "Creating Client..."
client = User.create!(
  email: "cliente@gmail.com",
  password: "password123",
  password_confirmation: "password123",
  name: "María López",
  phone: "3157654321",
  role: :client
)
puts "✅ Client created: #{client.email}"

puts "\n✨ Seeding completed!"
puts "\n📊 Summary:"
puts "   Super Admins: #{User.super_admin.count}"
puts "   Admins: #{User.admin.count}"
puts "   Employees: #{User.employee.count}"
puts "   Clients: #{User.client.count}"
puts "   Total Users: #{User.count}"
puts "\n🔑 Test credentials (all passwords: password123):"
puts "   Super Admin: superadmin@bokio.com"
puts "   Admin: admin@barberia.com"
puts "   Employee: empleado@barberia.com"
puts "   Client: cliente@gmail.com"

# Create Businesses
puts "\n🏢 Creating Businesses..."
Business.destroy_all

business1 = admin.businesses.create!(
  name: "Barbería Los Amigos",
  description: "La mejor barbería de la ciudad. Cortes modernos y clásicos.",
  address: "Calle 123 #45-67, Bogotá",
  phone: "3001234567",
  opening_time: "08:00",
  closing_time: "18:00",
  break_start_time: "12:00",
  break_end_time: "13:00"
)
puts "✅ Business created: #{business1.name} (slug: #{business1.slug})"

business2 = admin.businesses.create!(
  name: "Spa Relax",
  description: "Spa y centro de relajación",
  address: "Carrera 7 #80-45, Bogotá",
  phone: "3109876543",
  opening_time: "09:00",
  closing_time: "20:00"
)
puts "✅ Business created: #{business2.name} (slug: #{business2.slug})"

# Create Subscriptions
puts "\n💳 Creating Subscriptions..."

business1.create_subscription!(
  plan: :basic,
  started_at: Time.current,
  expires_at: 1.month.from_now,
  status: :active
)
puts "✅ Subscription created for #{business1.name}: Basic plan"

business2.create_subscription!(
  plan: :pro,
  started_at: Time.current,
  expires_at: 1.month.from_now,
  status: :active
)
puts "✅ Subscription created for #{business2.name}: Pro plan"

# Create Employees
puts "\n👥 Creating Employees..."
emp1 = business1.employees.create!(
  user: employee,
  name: "Carlos Gómez",
  email: "empleado@barberia.com",
  phone: "3109876543",
  status: :available
)
puts "✅ Employee created: #{emp1.name} (linked to user account)"

# Note: business1 has basic plan (max 2 employees), keeping 1 to allow authorization tests to create another
emp2 = business2.employees.create!(
  name: "Ana García",
  email: "ana@sparelax.com",
  phone: "3157654321",
  status: :available
)
puts "✅ Employee created: #{emp2.name}"

# Create Services
puts "\n💈 Creating Services..."
service1 = business1.services.create!(
  name: "Corte de Cabello",
  description: "Corte moderno con acabados profesionales",
  price: 25000,
  duration: 30,
  active: true
)
puts "✅ Service created: #{service1.name} ($#{service1.price})"

service2 = business1.services.create!(
  name: "Barba",
  description: "Arreglo y diseño de barba",
  price: 15000,
  duration: 20,
  active: true
)
puts "✅ Service created: #{service2.name} ($#{service2.price})"

service3 = business1.services.create!(
  name: "Corte + Barba Combo",
  description: "Combo completo de corte y arreglo de barba",
  price: 35000,
  duration: 45,
  active: true
)
puts "✅ Service created: #{service3.name} ($#{service3.price})"

service4 = business2.services.create!(
  name: "Masaje Relajante",
  description: "Masaje de cuerpo completo 60 minutos",
  price: 80000,
  duration: 60,
  active: true
)
puts "✅ Service created: #{service4.name} ($#{service4.price})"

service5 = business2.services.create!(
  name: "Facial",
  description: "Limpieza facial profunda",
  price: 60000,
  duration: 45,
  active: true
)
puts "✅ Service created: #{service5.name} ($#{service5.price})"

# Assign services to employees
puts "\n🔗 Assigning Services to Employees..."
emp1.services << [service1, service2, service3]
puts "✅ #{emp1.name} can provide: #{emp1.services.pluck(:name).join(', ')}"

emp2.services << [service4, service5]
puts "✅ #{emp2.name} can provide: #{emp2.services.pluck(:name).join(', ')}"

# Create Tickets
puts "\n🎫 Creating Tickets..."
ticket1 = business1.tickets.create!(
  client: client,
  employee: emp1,
  status: :in_progress,
  started_at: 30.minutes.ago
)
ticket1.services << [service1, service2]
puts "✅ Ticket created: #{ticket1.ticket_number} (in progress - #{client.name})"

ticket2 = business1.tickets.create!(
  client: client,
  status: :waiting
)
ticket2.services << [service3]
puts "✅ Ticket created: #{ticket2.ticket_number} (waiting - #{client.name})"

# Create additional client for more tickets
client2 = User.create!(
  email: "cliente2@gmail.com",
  password: "password123",
  password_confirmation: "password123",
  name: "Roberto Sánchez",
  phone: "3208765432",
  role: :client
)
puts "✅ Second client created: #{client2.email}"

ticket3 = business1.tickets.create!(
  client: client2,
  status: :waiting
)
ticket3.services << [service1]
puts "✅ Ticket created: #{ticket3.ticket_number} (waiting - #{client2.name})"

ticket4 = business2.tickets.create!(
  client: client,
  employee: emp2,
  status: :completed,
  started_at: 2.hours.ago,
  completed_at: 1.hour.ago
)
ticket4.services << [service4, service5]
puts "✅ Ticket created: #{ticket4.ticket_number} (completed - #{client.name})"

puts "\n📊 Final Summary:"
puts "   Total Users: #{User.count}"
puts "   Total Businesses: #{Business.count}"
puts "   Total Subscriptions: #{Subscription.count}"
puts "   Total Employees: #{Employee.count}"
puts "   Total Services: #{Service.count}"
puts "   Total Tickets: #{Ticket.count}"
puts "\n🎯 Test Business URLs:"
puts "   #{business1.name}: /api/v1/businesses (slug: #{business1.slug})"
puts "   #{business2.name}: /api/v1/businesses (slug: #{business2.slug})"
