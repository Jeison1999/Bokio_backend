#!/bin/bash

# Script de prueba de validaciones de suscripción
# Prueba límites de empleados por plan y suspensión por falta de pago

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
# AUTENTICACIÓN
# ========================================
print_header "Autenticando usuarios"

# Admin con plan Basic (Barbería Los Amigos - máximo 2 empleados)
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"admin@barberia.com","password":"password123"}}')
ADMIN_TOKEN=$(echo $RESPONSE | jq -r '.token')
echo -e "${GREEN}✓${NC} Admin autenticado (plan Basic)"

# Obtener business con plan Basic
BUSINESSES=$(curl -s -X GET "$BASE_URL/businesses" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
BUSINESS_BASIC_ID=$(echo $BUSINESSES | jq -r '.[0].id')
BUSINESS_BASIC_NAME=$(echo $BUSINESSES | jq -r '.[0].name')
SUBSCRIPTION_PLAN=$(echo $BUSINESSES | jq -r '.[0].subscription.plan')
MAX_EMPLOYEES=$(echo $BUSINESSES | jq -r '.[0].subscription.max_employees')

echo -e "${YELLOW}ℹ${NC} Business: $BUSINESS_BASIC_NAME"
echo -e "${YELLOW}ℹ${NC} Plan: $SUBSCRIPTION_PLAN (máximo $MAX_EMPLOYEES empleados)"

# Contar empleados existentes
EMPLOYEES=$(curl -s -X GET "$BASE_URL/businesses/$BUSINESS_BASIC_ID/employees" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
CURRENT_EMPLOYEES=$(echo $EMPLOYEES | jq 'length')
echo -e "${YELLOW}ℹ${NC} Empleados actuales: $CURRENT_EMPLOYEES/$MAX_EMPLOYEES"

# ========================================
# TEST 1: Crear empleados hasta el límite
# ========================================
print_header "Test: Límite de empleados por plan"

# Calcular cuántos empleados faltan para llegar al límite
REMAINING=$((MAX_EMPLOYEES - CURRENT_EMPLOYEES))

if [ $REMAINING -gt 0 ]; then
    # Crear empleado hasta llegar al límite
    for i in $(seq 1 $REMAINING); do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_BASIC_ID/employees" \
          -H "Authorization: Bearer $ADMIN_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{
            \"employee\": {
              \"name\": \"Empleado Test $i\",
              \"email\": \"empleado$i@test.com\",
              \"phone\": \"300000000$i\",
              \"status\": \"available\"
            }
          }")
        print_test "Crear empleado $((CURRENT_EMPLOYEES + i))/$MAX_EMPLOYEES" "201" "$STATUS"
    done
fi

# Intentar crear un empleado más (debe fallar)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_BASIC_ID/employees" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "employee": {
      "name": "Empleado Excedente",
      "email": "excedente@test.com",
      "phone": "3009999999",
      "status": "available"
    }
  }')
print_test "NO puede crear empleado excediendo límite" "422" "$STATUS"

# ========================================
# TEST 2: Crear servicio con suscripción activa
# ========================================
print_header "Test: Operaciones con suscripción activa"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_BASIC_ID/services" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "service": {
      "name": "Servicio Test",
      "description": "Test",
      "price": 30000,
      "duration": 45
    }
  }')
print_test "Puede crear servicio con suscripción activa" "201" "$STATUS"

# ========================================
# TEST 3: Suspender suscripción
# ========================================
print_header "Test: Negocio con suscripción suspendida"

# Suspender la suscripción usando Rails console
echo -e "${YELLOW}ℹ${NC} Suspendiendo suscripción del negocio..."
bin/rails runner "Business.find($BUSINESS_BASIC_ID).suspend_for_non_payment!" > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Suscripción suspendida"

# Intentar crear empleado con suscripción suspendida (debe fallar)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_BASIC_ID/employees" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "employee": {
      "name": "Empleado Post-Suspensión",
      "email": "postsuspension@test.com",
      "phone": "3008888888",
      "status": "available"
    }
  }')
print_test "NO puede crear empleado con suscripción suspendida" "402" "$STATUS"

# Intentar crear servicio con suscripción suspendida (debe fallar)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_BASIC_ID/services" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "service": {
      "name": "Servicio Post-Suspensión",
      "description": "Test",
      "price": 20000,
      "duration": 30
    }
  }')
print_test "NO puede crear servicio con suscripción suspendida" "402" "$STATUS"

# Intentar crear ticket con suscripción suspendida (debe fallar)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_BASIC_ID/tickets" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')
print_test "NO puede crear ticket con suscripción suspendida" "402" "$STATUS"

# ========================================
# TEST 4: Leer operaciones permitidas
# ========================================
print_header "Test: Operaciones de lectura con suscripción suspendida"

# Listar empleados (debe funcionar)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/businesses/$BUSINESS_BASIC_ID/employees" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Puede listar empleados aunque esté suspendido" "200" "$STATUS"

# Listar servicios (debe funcionar)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/businesses/$BUSINESS_BASIC_ID/services" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Puede listar servicios aunque esté suspendido" "200" "$STATUS"

# Ver cola de tickets (debe funcionar)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/businesses/$BUSINESS_BASIC_ID/tickets/queue" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Puede ver cola de tickets aunque esté suspendido" "200" "$STATUS"

# ========================================
# TEST 5: Reactivar suscripción
# ========================================
print_header "Test: Reactivar suscripción"

echo -e "${YELLOW}ℹ${NC} Reactivando suscripción..."
bin/rails runner "
  business = Business.find($BUSINESS_BASIC_ID)
  business.subscription.update(status: :active, expires_at: 1.month.from_now)
  business.update(active: true)
" > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Suscripción reactivada"

# Crear servicio después de reactivar (debe funcionar)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_BASIC_ID/services" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "service": {
      "name": "Servicio Post-Reactivación",
      "description": "Test",
      "price": 40000,
      "duration": 60
    }
  }')
print_test "Puede crear servicio después de reactivar" "201" "$STATUS"

# ========================================
# TEST 6: Verificar rake task
# ========================================
print_header "Test: Rake task de suspensión automática"

# Expirar una suscripción
echo -e "${YELLOW}ℹ${NC} Expirando suscripción..."
bin/rails runner "Business.find($BUSINESS_BASIC_ID).subscription.update(expires_at: 1.day.ago)" > /dev/null 2>&1

# Ejecutar rake task
OUTPUT=$(bin/rails subscriptions:suspend_expired 2>&1)
SUSPENDED_COUNT=$(echo "$OUTPUT" | grep "Businesses suspended:" | awk '{print $3}')

if [ "$SUSPENDED_COUNT" -ge "1" ]; then
    echo -e "${GREEN}✓${NC} Rake task suspendió $SUSPENDED_COUNT negocio(s)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Rake task no suspendió negocios expirados"
    ((TESTS_FAILED++))
fi

# Verificar que el negocio fue suspendido
BUSINESS_INFO=$(curl -s -X GET "$BASE_URL/businesses/$BUSINESS_BASIC_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
IS_ACTIVE=$(echo $BUSINESS_INFO | jq -r '.active')
SUBSCRIPTION_STATUS=$(echo $BUSINESS_INFO | jq -r '.subscription.status')

if [ "$IS_ACTIVE" == "false" ] && [ "$SUBSCRIPTION_STATUS" == "suspended" ]; then
    echo -e "${GREEN}✓${NC} Negocio correctamente marcado como suspendido"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Negocio no fue marcado como suspendido"
    ((TESTS_FAILED++))
fi

# ========================================
# RESUMEN
# ========================================
print_header "Resumen de Tests"
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
echo -e "${GREEN}Pasados: $TESTS_PASSED/$TOTAL_TESTS${NC}"
echo -e "${RED}Fallados: $TESTS_FAILED/$TOTAL_TESTS${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ Todos los tests de validación de suscripción pasaron!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Algunos tests fallaron${NC}"
    exit 1
fi
