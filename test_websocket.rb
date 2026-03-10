#!/usr/bin/env ruby

require 'websocket-client-simple'
require 'json'
require 'net/http'
require 'uri'

# Colores para output
RED = "\e[31m"
GREEN = "\e[32m"
YELLOW = "\e[33m"
BLUE = "\e[34m"
RESET = "\e[0m"

BASE_URL = 'http://localhost:3000'
WS_URL = 'ws://localhost:3000/cable'

# Contador de tests
TESTS_PASSED = []
TESTS_FAILED = []

def print_test(name, passed, message = nil)
  if passed
    puts "#{GREEN}✓#{RESET} #{name}"
    TESTS_PASSED << name
  else
    puts "#{RED}✗#{RESET} #{name}"
    puts "  #{RED}Error: #{message}#{RESET}" if message
    TESTS_FAILED << name
  end
end

def print_header(text)
  puts "\n#{BLUE}═══ #{text} ═══#{RESET}"
end

def print_info(text)
  puts "#{YELLOW}ℹ#{RESET} #{text}"
end

# Función para hacer requests HTTP
def http_request(method, path, token = nil, body = nil)
  uri = URI("#{BASE_URL}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  
  case method
  when :post
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = body.to_json if body
  when :get
    request = Net::HTTP::Get.new(uri.path)
  end
  
  request['Authorization'] = "Bearer #{token}" if token
  
  response = http.request(request)
  JSON.parse(response.body) rescue response.body
end

# ========================================
# PASO 1: Autenticación
# ========================================
print_header("Autenticación vía REST API")

login_response = http_request(:post, '/api/v1/auth/sign_in', nil, {
  user: {
    email: 'admin@barberia.com',
    password: 'password123'
  }
})

if login_response['token']
  TOKEN = login_response['token']
  USER_ID = login_response['data']['id']
  print_test("Login exitoso", true)
  print_info("Token obtenido: #{TOKEN[0..20]}...")
else
  print_test("Login exitoso", false, "No se obtuvo token")
  exit 1
end

# Obtener business_id
business_response = http_request(:get, '/api/v1/businesses', TOKEN)
BUSINESS_ID = business_response[0]['id']

if BUSINESS_ID
  print_test("Business ID obtenido", true)
  print_info("Business ID: #{BUSINESS_ID}")
else
  print_test("Business ID obtenido", false, "No se encontró business")
  exit 1
end

# ========================================
# PASO 2: Conexión WebSocket
# ========================================
print_header("Conexión WebSocket a ActionCable")

messages_received = []
connected = false
subscribed = false

ws = WebSocket::Client::Simple.connect("#{WS_URL}?token=#{TOKEN}")

ws.on :open do
  print_test("WebSocket conectado", true)
  connected = true
end

ws.on :message do |msg|
  data = JSON.parse(msg.data)
  messages_received << data
  
  case data['type']
  when 'welcome'
    print_info("Recibido mensaje de bienvenida")
  when 'confirm_subscription'
    print_test("Suscripción confirmada", true)
    print_info("Canal: queue_business_#{BUSINESS_ID}")
    subscribed = true
  when nil
    # Mensaje de broadcast
    if data['message']
      print_info("📨 Broadcast recibido:")
      puts JSON.pretty_generate(data['message'])
      
      # Validar estructura del broadcast
      msg_data = data['message']
      has_action = msg_data.key?('action')
      has_ticket = msg_data.key?('ticket')
      has_queue = msg_data.key?('queue')
      
      print_test("Broadcast contiene 'action'", has_action)
      print_test("Broadcast contiene 'ticket'", has_ticket)
      print_test("Broadcast contiene 'queue'", has_queue)
      
      if has_action && msg_data['action'] == 'ticket_created'
        print_test("Action es 'ticket_created'", true)
      end
    end
  end
end

ws.on :error do |e|
  # Ignorar errores de cierre de conexión
  unless e.message.include?('stream closed')
    print_test("Sin errores de WebSocket", false, e.message)
  end
end

ws.on :close do |e|
  print_info("WebSocket cerrado")
end

# Esperar conexión
sleep 1

unless connected
  print_test("WebSocket conectado", false, "Timeout esperando conexión")
  exit 1
end

# ========================================
# PASO 3: Suscripción al canal
# ========================================
print_header("Suscripción al QueueChannel")

subscribe_message = {
  command: 'subscribe',
  identifier: JSON.generate({
    channel: 'QueueChannel',
    business_id: BUSINESS_ID
  })
}

ws.send(subscribe_message.to_json)

# Esperar confirmación de suscripción
sleep 1

unless subscribed
  print_test("Suscripción confirmada", false, "No se recibió confirmación")
  exit 1
end

# ========================================
# PASO 4: Crear Ticket y verificar broadcast
# ========================================
print_header("Creando Ticket y esperando broadcast")

messages_before = messages_received.size
print_info("Creando ticket vía REST API...")

new_ticket = http_request(:post, "/api/v1/businesses/#{BUSINESS_ID}/tickets", TOKEN, {
  ticket: {
    customer_name: "WebSocket Test Client",
    customer_phone: "555-0101"
  }
})

if new_ticket.dig('data', 'id')
  print_test("Ticket creado correctamente", true)
  print_info("Ticket ID: #{new_ticket['data']['id']}")
  print_info("Ticket Number: #{new_ticket['data']['attributes']['ticket_number']}")
else
  print_test("Ticket creado correctamente", false, "Error creando ticket")
end

# Esperar broadcast
print_info("Esperando broadcast por ActionCable...")
sleep 2

messages_after = messages_received.size
new_messages = messages_after - messages_before

if new_messages > 0
  print_test("Broadcast recibido después de crear ticket", true)
else
  print_test("Broadcast recibido después de crear ticket", false, "No se recibió ningún mensaje")
end

# ========================================
# PASO 5: Actualizar Ticket y verificar broadcast
# ========================================
print_header("Iniciando Ticket y esperando broadcast")

ticket_id = new_ticket['data']['id']
messages_before = messages_received.size

updated_ticket = http_request(:post, "/api/v1/businesses/#{BUSINESS_ID}/tickets/#{ticket_id}/start", TOKEN)

if updated_ticket.dig('data', 'attributes', 'status') == 'in_progress'
  print_test("Ticket iniciado correctamente", true)
  print_info("Status: #{updated_ticket['data']['attributes']['status']}")
elsif updated_ticket['status'] == 'in_progress'
  print_test("Ticket iniciado correctamente", true)
  print_info("Status: #{updated_ticket['status']}")
else
  print_test("Ticket iniciado correctamente", false, "Respuesta: #{updated_ticket.inspect}")
end

# Esperar broadcast
sleep 2

messages_after = messages_received.size
new_messages = messages_after - messages_before

if new_messages > 0
  print_test("Broadcast recibido después de iniciar ticket", true)
  
  # Verificar que haya mensajes de broadcast con action: 'ticket_updated'
  broadcast_messages = messages_received.select { |m| m.is_a?(Hash) && m['message'].is_a?(Hash) && m['message']['action'] }
  if broadcast_messages.any?
    updated_broadcasts = broadcast_messages.select { |m| m['message']['action'] == 'ticket_updated' }
    if updated_broadcasts.any?
      print_test("Action es 'ticket_updated'", true)
    else
      print_test("Action es 'ticket_updated'", false, "Actions recibidos: #{broadcast_messages.map { |m| m['message']['action'] }.join(', ')}")
    end
  else
    print_test("Action es 'ticket_updated'", false, "No se recibieron broadcasts con action")
  end
else
  print_test("Broadcast recibido después de iniciar ticket", false)
end

# ========================================
# RESUMEN
# ========================================
ws.close

print_header("Resumen de Tests")
puts "#{GREEN}Pasados: #{TESTS_PASSED.size}#{RESET}"
puts "#{RED}Fallados: #{TESTS_FAILED.size}#{RESET}"

if TESTS_FAILED.empty?
  puts "\n#{GREEN}✓ Todos los tests de WebSocket pasaron!#{RESET}"
  exit 0
else
  puts "\n#{RED}✗ Algunos tests fallaron#{RESET}"
  exit 1
end
