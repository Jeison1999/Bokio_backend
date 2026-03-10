#!/bin/bash

# Script de prueba de autorización con Pundit
# Prueba que los usuarios solo puedan acceder a los recursos según su rol

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:3000/api/v1"

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0

# Función para imprimir encabezados
print_header() {
    echo -e "\n${BLUE}═══ $1 ═══${NC}"
}

# Función para imprimir resultados de tests
print_test() {
    local test_name="$1"
    local expected_status="$2"
    local actual_status="$3"
    
    if [ "$expected_status" == "$actual_status" ]; then
        echo -e "${GREEN}✓${NC} $test_name (status: $actual_status)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name (expected: $expected_status, got: $actual_status)"
        ((TESTS_FAILED++))
    fi
}

# Resetear base de datos con seeds
print_header "Preparando base de datos"
bin/rails db:seed:replant > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Base de datos reseteada"

# ========================================
# AUTENTICACIÓN DE USUARIOS
# ========================================
print_header "Autenticando usuarios"

# Super Admin
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"superadmin@bokio.com","password":"password123"}}')
SUPER_ADMIN_TOKEN=$(echo $RESPONSE | jq -r '.token')
echo -e "${GREEN}✓${NC} Super Admin autenticado"

# Admin (dueño de Barbería Los Amigos)
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"admin@barberia.com","password":"password123"}}')
ADMIN_TOKEN=$(echo $RESPONSE | jq -r '.token')
ADMIN_ID=$(echo $RESPONSE | jq -r '.data.id')
echo -e "${GREEN}✓${NC} Admin autenticado"

# Employee
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"empleado@barberia.com","password":"password123"}}')
EMPLOYEE_TOKEN=$(echo $RESPONSE | jq -r '.token')
echo -e "${GREEN}✓${NC} Employee autenticado"

# Client
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"cliente@gmail.com","password":"password123"}}')
CLIENT_TOKEN=$(echo $RESPONSE | jq -r '.token')
echo -e "${GREEN}✓${NC} Client autenticado"

# Obtener IDs de negocios
BUSINESSES=$(curl -s -X GET "$BASE_URL/businesses" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
BUSINESS_1_ID=$(echo $BUSINESSES | jq -r '.[0].id')
BUSINESS_2_ID=$(echo $BUSINESSES | jq -r '.[1].id')

echo -e "${YELLOW}ℹ${NC} Business 1 ID: $BUSINESS_1_ID (Barbería Los Amigos)"
echo -e "${YELLOW}ℹ${NC} Business 2 ID: $BUSINESS_2_ID (Spa Relax)"

# ========================================
# TEST 1: BUSINESSES - Index
# ========================================
print_header "Test: Listar Negocios"

# Super Admin puede ver todos
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/businesses" \
  -H "Authorization: Bearer $SUPER_ADMIN_TOKEN")
print_test "Super Admin puede listar negocios" "200" "$STATUS"

# Admin puede ver sus negocios
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/businesses" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Admin puede listar negocios" "200" "$STATUS"

# Client puede ver negocios (públicos)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/businesses" \
  -H "Authorization: Bearer $CLIENT_TOKEN")
print_test "Client puede listar negocios" "200" "$STATUS"

# ========================================
# TEST 2: BUSINESSES - Create
# ========================================
print_header "Test: Crear Negocio"

# Admin puede crear negocio
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "business": {
      "name": "Test Business",
      "description": "Test",
      "address": "Test Address",
      "phone": "1234567890"
    }
  }')
print_test "Admin puede crear negocio" "201" "$STATUS"

# Client NO puede crear negocio
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "business": {
      "name": "Test Business 2",
      "description": "Test",
      "address": "Test Address",
      "phone": "1234567890"
    }
  }')
print_test "Client NO puede crear negocio" "403" "$STATUS"

# ========================================
# TEST 3: BUSINESSES - Update
# ========================================
print_header "Test: Actualizar Negocio"

# Admin puede actualizar SU negocio
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/businesses/$BUSINESS_1_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"business":{"description":"Updated description"}}')
print_test "Admin puede actualizar su negocio" "200" "$STATUS"

# Client NO puede actualizar ningún negocio
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/businesses/$BUSINESS_1_ID" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"business":{"description":"Hacked!"}}')
print_test "Client NO puede actualizar negocio" "403" "$STATUS"

# ========================================
# TEST 4: EMPLOYEES - Create
# ========================================
print_header "Test: Crear Empleado"

# Admin puede crear empleado en SU negocio
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/employees" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "employee": {
      "name": "Test Employee",
      "email": "test@employee.com",
      "phone": "1234567890",
      "status": "available"
    }
  }')
print_test "Admin puede crear empleado en su negocio" "201" "$STATUS"

# Client NO puede crear empleado
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/employees" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "employee": {
      "name": "Hacker Employee",
      "email": "hacker@employee.com",
      "phone": "1234567890",
      "status": "available"
    }
  }')
print_test "Client NO puede crear empleado" "403" "$STATUS"

# ========================================
# TEST 5: SERVICES - Create
# ========================================
print_header "Test: Crear Servicio"

# Admin puede crear servicio en SU negocio
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/services" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "service": {
      "name": "Test Service",
      "description": "Test",
      "price": 50000,
      "duration": 30
    }
  }')
print_test "Admin puede crear servicio en su negocio" "201" "$STATUS"

# Employee NO puede crear servicio
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/services" \
  -H "Authorization: Bearer $EMPLOYEE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "service": {
      "name": "Hacker Service",
      "description": "Test",
      "price": 50000,
      "duration": 30
    }
  }')
print_test "Employee NO puede crear servicio" "403" "$STATUS"

# ========================================
# TEST 6: TICKETS - Create
# ========================================
print_header "Test: Crear Ticket"

# Client puede crear ticket
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/tickets" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')
print_test "Client puede crear ticket" "201" "$STATUS"

# Admin también puede crear ticket
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/tickets" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')
print_test "Admin puede crear ticket" "201" "$STATUS"

# ========================================
# TEST 7: TICKETS - Start/Complete
# ========================================
print_header "Test: Iniciar/Completar Ticket"

# Obtener un ticket en estado waiting
TICKETS=$(curl -s -X GET "$BASE_URL/businesses/$BUSINESS_1_ID/tickets?status=waiting" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
TICKET_ID=$(echo $TICKETS | jq -r '.[0].data.id // empty')

if [ -z "$TICKET_ID" ] || [ "$TICKET_ID" == "null" ]; then
    echo -e "${YELLOW}⚠${NC} No hay tickets en estado waiting, creando uno..."
    # Crear un ticket para el test
    NEW_TICKET=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/tickets" \
      -H "Authorization: Bearer $CLIENT_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{}')
    TICKET_ID=$(echo $NEW_TICKET | jq -r '.data.id')
fi

# Employee puede iniciar ticket
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/tickets/$TICKET_ID/start" \
  -H "Authorization: Bearer $EMPLOYEE_TOKEN")
print_test "Employee puede iniciar ticket" "200" "$STATUS"

# Employee puede completar ticket
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/tickets/$TICKET_ID/complete" \
  -H "Authorization: Bearer $EMPLOYEE_TOKEN")
print_test "Employee puede completar ticket" "200" "$STATUS"

# Crear otro ticket para probar que client no puede iniciar
NEW_TICKET=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/tickets" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')
TICKET_ID_2=$(echo $NEW_TICKET | jq -r '.data.id')

# Client NO puede iniciar ticket
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_1_ID/tickets/$TICKET_ID_2/start" \
  -H "Authorization: Bearer $CLIENT_TOKEN")
print_test "Client NO puede iniciar ticket" "403" "$STATUS"

# ========================================
# TEST 8: SUPER ADMIN - Acceso total
# ========================================
print_header "Test: Super Admin - Acceso Total"

# Super Admin puede actualizar cualquier negocio
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/businesses/$BUSINESS_2_ID" \
  -H "Authorization: Bearer $SUPER_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"business":{"description":"Super Admin can edit"}}')
print_test "Super Admin puede actualizar cualquier negocio" "200" "$STATUS"

# Super Admin puede crear empleado en cualquier negocio
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_2_ID/employees" \
  -H "Authorization: Bearer $SUPER_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "employee": {
      "name": "Super Admin Employee",
      "email": "superadmin@employee.com",
      "phone": "1234567890",
      "status": "available"
    }
  }')
print_test "Super Admin puede crear empleado en cualquier negocio" "201" "$STATUS"

# ========================================
# RESUMEN
# ========================================
print_header "Resumen de Tests"
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
echo -e "${GREEN}Pasados: $TESTS_PASSED/$TOTAL_TESTS${NC}"
echo -e "${RED}Fallados: $TESTS_FAILED/$TOTAL_TESTS${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ Todos los tests de autorización pasaron!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Algunos tests fallaron${NC}"
    exit 1
fi
