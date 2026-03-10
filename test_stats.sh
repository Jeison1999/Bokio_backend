#!/bin/bash

# Script de prueba del sistema de estadísticas
# Prueba estadísticas para admins y super admins

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
BUSINESS_ID=$(curl -s -X GET "$BASE_URL/businesses" -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].id')
echo -e "${GREEN}✓${NC} Admin autenticado (Business ID: $BUSINESS_ID)"

# Cliente
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"cliente@gmail.com","password":"password123"}}')
CLIENT_TOKEN=$(echo $RESPONSE | jq -r '.token')
echo -e "${GREEN}✓${NC} Cliente autenticado"

# ========================================
# PREPARAR DATOS: Crear tickets y marcar como pagados
# ========================================
print_header "Preparando datos de prueba"

# Limpiar tickets existentes
bin/rails runner "Business.find($BUSINESS_ID).tickets.destroy_all" > /dev/null 2>&1

# Obtener servicio ID
SERVICE_ID=$(curl -s -X GET "$BASE_URL/businesses/$BUSINESS_ID/services" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].data.attributes.id')

# Crear 3 tickets completados y pagados
for i in {1..3}; do
    RESPONSE=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
      -H "Authorization: Bearer $CLIENT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"ticket\":{\"service_ids\":[${SERVICE_ID}]}}")
    TICKET_ID=$(echo $RESPONSE | jq -r '.data.id')
    
    # Iniciar ticket
    curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET_ID/start" \
      -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null
    
    # Completar ticket
    curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET_ID/complete" \
      -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null
    
    # Marcar como pagado
    curl -s -X PATCH "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET_ID/mark_as_paid" \
      -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null
done

echo -e "${GREEN}✓${NC} 3 tickets creados, completados y pagados"

# Crear 2 tickets completados pero NO pagados
for i in {1..2}; do
    RESPONSE=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
      -H "Authorization: Bearer $CLIENT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"ticket\":{\"service_ids\":[${SERVICE_ID}]}}")
    TICKET_ID=$(echo $RESPONSE | jq -r '.data.id')
    
    curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET_ID/start" \
      -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null
    curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET_ID/complete" \
      -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null
done

echo -e "${GREEN}✓${NC} 2 tickets completados pero no pagados"

# ========================================
# TEST 1: Admin puede ver estadísticas de su negocio
# ========================================
print_header "Test: Estadísticas del negocio (Admin)"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/businesses/$BUSINESS_ID/stats" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Admin puede acceder a stats del negocio" "200" "$STATUS"

# Obtener resumen de estadísticas
STATS=$(curl -s -X GET "$BASE_URL/businesses/$BUSINESS_ID/stats?period=today" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

TOTAL_TICKETS=$(echo $STATS | jq -r '.summary.total_tickets')
PAID_TICKETS=$(echo $STATS | jq -r '.summary.paid_tickets')
UNPAID=$(echo $STATS | jq -r '.summary.unpaid_tickets')

if [ "$TOTAL_TICKETS" == "5" ]; then
    echo -e "${GREEN}✓${NC} Total tickets correcto: $TOTAL_TICKETS"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Total tickets incorrecto (esperado: 5, got: $TOTAL_TICKETS)"
    ((TESTS_FAILED++))
fi

if [ "$PAID_TICKETS" == "3" ]; then
    echo -e "${GREEN}✓${NC} Tickets pagados correcto: $PAID_TICKETS"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Tickets pagados incorrecto (esperado: 3, got: $PAID_TICKETS)"
    ((TESTS_FAILED++))
fi

if [ "$UNPAID" == "2" ]; then
    echo -e "${GREEN}✓${NC} Tickets sin pagar correcto: $UNPAID"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Tickets sin pagar incorrecto (esperado: 2, got: $UNPAID)"
    ((TESTS_FAILED++))
fi

# ========================================
# TEST 2: Dashboard con múltiples períodos
# ========================================
print_header "Test: Dashboard del negocio"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/businesses/$BUSINESS_ID/stats/dashboard" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Admin puede acceder al dashboard" "200" "$STATUS"

DASHBOARD=$(curl -s -X GET "$BASE_URL/businesses/$BUSINESS_ID/stats/dashboard" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

# Verificar que tiene sección "today"
HAS_TODAY=$(echo $DASHBOARD | jq -r '.today.total_tickets')
if [ ! -z "$HAS_TODAY" ] && [ "$HAS_TODAY" != "null" ]; then
    echo -e "${GREEN}✓${NC} Dashboard contiene estadísticas de hoy"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Dashboard no contiene estadísticas de hoy"
    ((TESTS_FAILED++))
fi

# Verificar que tiene gráfica diaria
HAS_CHART=$(echo $DASHBOARD | jq -r '.daily_chart | length')
if [ "$HAS_CHART" -gt "0" ]; then
    echo -e "${GREEN}✓${NC} Dashboard contiene gráfica diaria ($HAS_CHART días)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Dashboard no contiene gráfica diaria"
    ((TESTS_FAILED++))
fi

# ========================================
# TEST 3: Estadísticas por empleado
# ========================================
print_header "Test: Estadísticas por empleado"

STATS=$(curl -s -X GET "$BASE_URL/businesses/$BUSINESS_ID/stats?period=today" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

EMPLOYEES_COUNT=$(echo $STATS | jq -r '.by_employee | length')
if [ "$EMPLOYEES_COUNT" -gt "0" ]; then
    echo -e "${GREEN}✓${NC} Tiene estadísticas por empleado ($EMPLOYEES_COUNT empleados)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} No tiene estadísticas por empleado"
    ((TESTS_FAILED++))
fi

# ========================================
# TEST 4: Cliente NO puede ver estadísticas
# ========================================
print_header "Test: Autorización - Cliente"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/businesses/$BUSINESS_ID/stats" \
  -H "Authorization: Bearer $CLIENT_TOKEN")
print_test "Cliente NO puede ver estadísticas" "403" "$STATUS"

# ========================================
# TEST 5: Super Admin puede ver overview de plataforma
# ========================================
print_header "Test: Super Admin - Overview de plataforma"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/admin/stats/overview?period=today" \
  -H "Authorization: Bearer $SUPER_ADMIN_TOKEN")
print_test "Super Admin puede acceder al overview" "200" "$STATUS"

OVERVIEW=$(curl -s -X GET "$BASE_URL/admin/stats/overview?period=today" \
  -H "Authorization: Bearer $SUPER_ADMIN_TOKEN")

# Verificar estructura del overview
HAS_PLATFORM=$(echo $OVERVIEW | jq -r '.platform_stats.total_tickets')
HAS_BUSINESSES=$(echo $OVERVIEW | jq -r '.businesses.total')
HAS_SUBSCRIPTIONS=$(echo $OVERVIEW | jq -r '.subscriptions.total')

if [ ! -z "$HAS_PLATFORM" ] && [ "$HAS_PLATFORM" != "null" ]; then
    echo -e "${GREEN}✓${NC} Overview contiene estadísticas de plataforma"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Overview no contiene estadísticas de plataforma"
    ((TESTS_FAILED++))
fi

if [ ! -z "$HAS_BUSINESSES" ] && [ "$HAS_BUSINESSES" != "null" ]; then
    echo -e "${GREEN}✓${NC} Overview contiene información de negocios (total: $HAS_BUSINESSES)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Overview no contiene información de negocios"
    ((TESTS_FAILED++))
fi

if [ ! -z "$HAS_SUBSCRIPTIONS" ] && [ "$HAS_SUBSCRIPTIONS" != "null" ]; then
    echo -e "${GREEN}✓${NC} Overview contiene información de suscripciones (total: $HAS_SUBSCRIPTIONS)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Overview no contiene información de suscripciones"
    ((TESTS_FAILED++))
fi

# ========================================
# TEST 6: Super Admin - Estadísticas de suscripciones
# ========================================
print_header "Test: Super Admin - Suscripciones"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/admin/stats/subscriptions" \
  -H "Authorization: Bearer $SUPER_ADMIN_TOKEN")
print_test "Super Admin puede ver stats de suscripciones" "200" "$STATUS"

SUB_STATS=$(curl -s -X GET "$BASE_URL/admin/stats/subscriptions" \
  -H "Authorization: Bearer $SUPER_ADMIN_TOKEN")

MRR=$(echo $SUB_STATS | jq -r '.monthly_recurring_revenue')
if [ ! -z "$MRR" ] && [ "$MRR" != "null" ]; then
    echo -e "${GREEN}✓${NC} Calcula MRR (Monthly Recurring Revenue): \$${MRR}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} No calcula MRR"
    ((TESTS_FAILED++))
fi

# ========================================
# TEST 7: Admin NO puede acceder a stats de super admin
# ========================================
print_header "Test: Autorización - Admin vs Super Admin"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/admin/stats/overview" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Admin NO puede acceder a stats de plataforma" "403" "$STATUS"

# ========================================
# TEST 8: Marcar ticket como pagado
# ========================================
print_header "Test: Marcar ticket como pagado"

# Crear nuevo ticket
RESPONSE=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"ticket\":{\"service_ids\":[${SERVICE_ID}]}}")
NEW_TICKET_ID=$(echo $RESPONSE | jq -r '.data.id')

# Intentar marcar como pagado SIN completar (debería fallar)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/businesses/$BUSINESS_ID/tickets/$NEW_TICKET_ID/mark_as_paid" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "NO puede marcar como pagado si no está completado" "422" "$STATUS"

# Completar ticket
curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$NEW_TICKET_ID/start" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null
curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$NEW_TICKET_ID/complete" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null

# Ahora sí marcar como pagado
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/businesses/$BUSINESS_ID/tickets/$NEW_TICKET_ID/mark_as_paid" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Marca como pagado ticket completado" "200" "$STATUS"

# Intentar marcar como pagado nuevamente (debería fallar)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/businesses/$BUSINESS_ID/tickets/$NEW_TICKET_ID/mark_as_paid" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "NO puede marcar como pagado si ya está pagado" "422" "$STATUS"

# ========================================
# RESUMEN
# ========================================
print_header "Resumen de Tests"
echo -e "Pasados: ${GREEN}$TESTS_PASSED${NC}/$((TESTS_PASSED + TESTS_FAILED))"
echo -e "Fallados: ${RED}$TESTS_FAILED${NC}/$((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ Todos los tests de estadísticas pasaron!${NC}\n"
    exit 0
else
    echo -e "\n${RED}✗ Algunos tests fallaron${NC}\n"
    exit 1
fi
