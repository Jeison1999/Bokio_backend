#!/bin/bash

# Script de prueba del sistema de notificaciones
# Prueba que los clientes reciban notificaciones cuando estén a 1 turno

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

# Admin (dueño de Barbería Los Amigos)
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"admin@barberia.com","password":"password123"}}')
ADMIN_TOKEN=$(echo $RESPONSE | jq -r '.token')
BUSINESS_ID=$(curl -s -X GET "$BASE_URL/businesses" -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].id')
echo -e "${GREEN}✓${NC} Admin autenticado (Business ID: $BUSINESS_ID)"

# Cliente 1
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"cliente@gmail.com","password":"password123"}}')
CLIENT1_TOKEN=$(echo $RESPONSE | jq -r '.token')
CLIENT1_ID=$(echo $RESPONSE | jq -r '.data.id')
echo -e "${GREEN}✓${NC} Cliente 1 autenticado"

# Cliente 2
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"cliente2@gmail.com","password":"password123"}}')
CLIENT2_TOKEN=$(echo $RESPONSE | jq -r '.token')
CLIENT2_ID=$(echo $RESPONSE | jq -r '.data.id')
echo -e "${GREEN}✓${NC} Cliente 2 autenticado"

# ========================================
# CREAR TICKETS PARA PROBAR NOTIFICACIONES
# ========================================
print_header "Creando tickets de prueba"

# Limpiar tickets existentes del negocio para tener cola limpia
bin/rails runner "Business.find($BUSINESS_ID).tickets.destroy_all" > /dev/null 2>&1
echo -e "${YELLOW}ℹ${NC} Tickets anteriores eliminados"

# Obtener servicio ID
SERVICE_ID=$(curl -s -X GET "$BASE_URL/businesses/$BUSINESS_ID/services" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].data.attributes.id')

# Cliente 1 crea ticket (será el primero en la cola)
RESPONSE=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Authorization: Bearer $CLIENT1_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"ticket\":{\"service_ids\":[${SERVICE_ID}]}}")
TICKET1_ID=$(echo $RESPONSE | jq -r '.data.id')
echo -e "${GREEN}✓${NC} Ticket 1 creado para Cliente 1"

# Cliente 2 crea ticket (será el segundo en la cola)
RESPONSE=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Authorization: Bearer $CLIENT2_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"ticket\":{\"service_ids\":[${SERVICE_ID}]}}")
TICKET2_ID=$(echo $RESPONSE | jq -r '.data.id')
echo -e "${GREEN}✓${NC} Ticket 2 creado para Cliente 2"

# Crear tercer ticket para probar que Cliente 2 recibe notificación "falta 1 turno"
# Usamos cliente@gmail.com nuevamente para tener 3 tickets en cola
RESPONSE=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Authorization: Bearer $CLIENT1_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"ticket\":{\"service_ids\":[${SERVICE_ID}]}}")
TICKET3_ID=$(echo $RESPONSE | jq -r '.data.id')
echo -e "${GREEN}✓${NC} Ticket 3 creado"

# ========================================
# TEST 1: Cliente NO tiene notificaciones inicialmente
# ========================================
print_header "Test: Estado inicial de notificaciones"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/notifications" \
  -H "Authorization: Bearer $CLIENT1_TOKEN")
print_test "Cliente puede acceder a endpoint de notificaciones" "200" "$STATUS"

UNREAD_COUNT=$(curl -s -X GET "$BASE_URL/notifications/unread" \
  -H "Authorization: Bearer $CLIENT1_TOKEN" | jq -r '.count')
if [ "$UNREAD_COUNT" == "0" ]; then
    echo -e "${GREEN}✓${NC} Cliente no tiene notificaciones no leídas inicialmente"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Cliente no debería tener notificaciones (tiene: $UNREAD_COUNT)"
    ((TESTS_FAILED++))
fi

# ========================================
# TEST 2: Completar primer ticket - Notificaciones se envían
# ========================================
print_header "Test: Notificaciones cuando se completa un ticket"

# Primero iniciar el ticket (no debería generar notificaciones)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET1_ID/start" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Ticket 1 iniciado correctamente" "200" "$STATUS"

sleep 1

# Verificar que NO hay notificaciones aún (porque solo iniciamos, no completamos)
UNREAD_COUNT=$(curl -s -X GET "$BASE_URL/notifications/unread" \
  -H "Authorization: Bearer $CLIENT2_TOKEN" | jq -r '.count')
if [ "$UNREAD_COUNT" == "0" ]; then
    echo -e "${GREEN}✓${NC} No hay notificaciones antes de completar ticket"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC}  Se generaron $UNREAD_COUNT notificaciones al iniciar (esperado 0)"
fi

# Admin completa el primer ticket (AQUÍ se generan las notificaciones)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET1_ID/complete" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Ticket 1 completado correctamente" "200" "$STATUS"

sleep 2  # Dar tiempo para que se creen las notificaciones

# Cliente 2 debería tener 1 notificación tipo "next_in_queue" (es el siguiente)
UNREAD_COUNT=$(curl -s -X GET "$BASE_URL/notifications/unread" \
  -H "Authorization: Bearer $CLIENT2_TOKEN" | jq -r '.count')
if [ "$UNREAD_COUNT" == "1" ]; then
    echo -e "${GREEN}✓${NC} Cliente 2 recibió notificación (es el siguiente)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Cliente 2 debería tener 1 notificación (tiene: $UNREAD_COUNT)"
    ((TESTS_FAILED++))
fi

# Verificar tipo de notificación (debería ser "next_in_queue" porque es el primero en espera)
NOTIF_TYPE=$(curl -s -X GET "$BASE_URL/notifications/unread" \
  -H "Authorization: Bearer $CLIENT2_TOKEN" | jq -r '.notifications[0].type')
if [ "$NOTIF_TYPE" == "next_in_queue" ]; then
    echo -e "${GREEN}✓${NC} Tipo de notificación correcto: next_in_queue"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Tipo incorrecto (esperado: next_in_queue, recibido: $NOTIF_TYPE)"
    ((TESTS_FAILED++))
fi

# Cliente 1 también debería tener 1 notificación tipo "one_away" (para su Ticket 3)
UNREAD_COUNT_C1=$(curl -s -X GET "$BASE_URL/notifications/unread" \
  -H "Authorization: Bearer $CLIENT1_TOKEN" | jq -r '.count')
if [ "$UNREAD_COUNT_C1" == "1" ]; then
    echo -e "${GREEN}✓${NC} Cliente 1 recibió notificación (falta 1 turno para Ticket 3)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Cliente 1 debería tener 1 notificación (tiene: $UNREAD_COUNT_C1)"
    ((TESTS_FAILED++))
fi

# Verificar tipo de notificación para Cliente 1
NOTIF_TYPE_C1=$(curl -s -X GET "$BASE_URL/notifications/unread" \
  -H "Authorization: Bearer $CLIENT1_TOKEN" | jq -r '.notifications[0].type')
if [ "$NOTIF_TYPE_C1" == "one_away" ]; then
    echo -e "${GREEN}✓${NC} Tipo de notificación correcto: one_away"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Tipo incorrecto (esperado: one_away, recibido: $NOTIF_TYPE_C1)"
    ((TESTS_FAILED++))
fi

# ========================================
# TEST 3: Completar segundo ticket - Cliente 1 (Ticket 3) recibe "next_in_queue"
# ========================================
print_header "Test: Notificación al completar segundo ticket"

# Admin inicia Ticket 2
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET2_ID/start" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Ticket 2 iniciado correctamente" "200" "$STATUS"

# Admin completa el segundo ticket
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET2_ID/complete" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
print_test "Ticket 2 completado correctamente" "200" "$STATUS"

sleep 2

# Cliente 1 debería tener ahora 2 notificaciones (one_away + next_in_queue)
TOTAL_COUNT=$(curl -s -X GET "$BASE_URL/notifications" \
  -H "Authorization: Bearer $CLIENT1_TOKEN" | jq '. | length')
if [ "$TOTAL_COUNT" == "2" ]; then
    echo -e "${GREEN}✓${NC} Cliente 1 recibió segunda notificación"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Cliente 1 debería tener 2 notificaciones (tiene: $TOTAL_COUNT)"
    ((TESTS_FAILED++))
fi

# ========================================
# TEST 4: Marcar notificación como leída
# ========================================
print_header "Test: Marcar notificaciones como leídas"

# Obtener ID de primera notificación de Cliente 2
NOTIF_ID=$(curl -s -X GET "$BASE_URL/notifications" \
  -H "Authorization: Bearer $CLIENT2_TOKEN" | jq -r '.[0].id')

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/notifications/$NOTIF_ID/mark_as_read" \
  -H "Authorization: Bearer $CLIENT2_TOKEN")
print_test "Notificación marcada como leída" "200" "$STATUS"

# ========================================
# TEST 5: Marcar todas las notificaciones como leídas
# ========================================
print_header "Test: Marcar todas como leídas"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/notifications/mark_all_as_read" \
  -H "Authorization: Bearer $CLIENT1_TOKEN")
print_test "Todas las notificaciones marcadas como leídas" "200" "$STATUS"

# Verificar que contador de no leídas es 0
UNREAD_COUNT=$(curl -s -X GET "$BASE_URL/notifications/unread" \
  -H "Authorization: Bearer $CLIENT1_TOKEN" | jq -r '.count')
if [ "$UNREAD_COUNT" == "0" ]; then
    echo -e "${GREEN}✓${NC} Todas las notificaciones fueron marcadas como leídas"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Deberían ser 0 no leídas (tiene: $UNREAD_COUNT)"
    ((TESTS_FAILED++))
fi

# ========================================
# RESUMEN
# ========================================
print_header "Resumen de Tests"
echo -e "Pasados: ${GREEN}$TESTS_PASSED${NC}/${TESTS_PASSED}+${TESTS_FAILED}"
echo -e "Fallados: ${RED}$TESTS_FAILED${NC}/${TESTS_PASSED}+${TESTS_FAILED}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ Todos los tests de notificaciones pasaron!${NC}\n"
    exit 0
else
    echo -e "\n${RED}✗ Algunos tests fallaron${NC}\n"
    exit 1
fi
