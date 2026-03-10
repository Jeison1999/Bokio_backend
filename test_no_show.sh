#!/bin/bash

BASE_URL="http://localhost:3000/api/v1"
PASS=0
FAIL=0

check() {
  local description="$1"
  local condition="$2"
  if [ "$condition" = "true" ]; then
    echo "✓ $description"
    PASS=$((PASS + 1))
  else
    echo "✗ $description"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "═══ Preparando base de datos ═══"
cd /workspaces/Bokio_backend && rails db:reset > /dev/null 2>&1
echo "✓ Base de datos reseteada"

echo ""
echo "═══ Autenticando usuarios ═══"

ADMIN=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"admin@barberia.com","password":"password123"}}')
ADMIN_TOKEN=$(echo $ADMIN | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.dig("data","token") || j["token"] || ""')
BUSINESS_ID=$(curl -s "$BASE_URL/businesses" -H "Authorization: Bearer $ADMIN_TOKEN" | ruby -r json -e 'j=JSON.parse(STDIN.read); d=j.is_a?(Array) ? j : j["data"]; puts d[0]["id"]')
echo "✓ Admin autenticado (Business ID: $BUSINESS_ID)"

CLIENT=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"cliente@gmail.com","password":"password123"}}')
CLIENT_TOKEN=$(echo $CLIENT | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.dig("data","token") || j["token"] || ""')
echo "✓ Cliente autenticado"

echo ""
echo "═══ Creando ticket en estado waiting ═══"

TICKET=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -d '{"ticket":{}}')
TICKET_ID=$(echo $TICKET | ruby -r json -e 'j=JSON.parse(STDIN.read); t=j["data"]||j; puts t["id"] || t.dig("data","id") || ""' 2>/dev/null)
TICKET_STATUS=$(echo $TICKET | ruby -r json -e 'j=JSON.parse(STDIN.read); t=j["data"]||j; a=t["attributes"]||t; puts a["status"]' 2>/dev/null)
echo "✓ Ticket creado (ID: $TICKET_ID, status: $TICKET_STATUS)"

echo ""
echo "═══ Test: Marcar como no_show ═══"

# Sólo admin/empleado puede marcar no_show
CLIENT_NO_SHOW=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET_ID/no_show" \
  -H "Authorization: Bearer $CLIENT_TOKEN")
check "Cliente NO puede marcar no_show (403)" "$([ "$CLIENT_NO_SHOW" = "403" ] && echo true || echo false)"

# Admin puede marcar no_show
NO_SHOW_RESP=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET_ID/no_show" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
NO_SHOW_STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET_ID/no_show" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

# Primera vez: debería ser 200
NO_SHOW_FIRST=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET_ID/no_show" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

# Crear nuevo ticket para test limpio
TICKET2=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -d '{"ticket":{}}')
TICKET2_ID=$(echo $TICKET2 | ruby -r json -e 'j=JSON.parse(STDIN.read); t=j["data"]||j; puts t["id"] || ""' 2>/dev/null)

NO_SHOW_OK=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET2_ID/no_show" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
check "Admin puede marcar ticket como no_show (200)" "$([ "$NO_SHOW_OK" = "200" ] && echo true || echo false)"

# Verificar que el status cambió
TICKET2_BODY=$(curl -s "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET2_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
TICKET2_STATUS=$(echo $TICKET2_BODY | ruby -r json -e 'j=JSON.parse(STDIN.read); t=j["data"]||j; a=t["attributes"]||t; puts a["status"]' 2>/dev/null)
check "Status del ticket es 'no_show'" "$([ "$TICKET2_STATUS" = "no_show" ] && echo true || echo false)"

echo ""
echo "═══ Test: no_show solo aplica a tickets en waiting ═══"

# Crear ticket y pasarlo a in_progress
TICKET3=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -d '{"ticket":{}}')
TICKET3_ID=$(echo $TICKET3 | ruby -r json -e 'j=JSON.parse(STDIN.read); t=j["data"]||j; puts t["id"] || ""' 2>/dev/null)

# Iniciar el ticket
curl -s -o /dev/null -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET3_ID/start" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# Intentar no_show en ticket in_progress
NO_SHOW_IN_PROGRESS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET3_ID/no_show" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
check "No se puede marcar no_show en ticket in_progress (422)" "$([ "$NO_SHOW_IN_PROGRESS" = "422" ] && echo true || echo false)"

# Crear ticket y completarlo, luego intentar no_show
TICKET4=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -d '{"ticket":{}}')
TICKET4_ID=$(echo $TICKET4 | ruby -r json -e 'j=JSON.parse(STDIN.read); t=j["data"]||j; puts t["id"] || ""' 2>/dev/null)
curl -s -o /dev/null -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET4_ID/start" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
curl -s -o /dev/null -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET4_ID/complete" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

NO_SHOW_COMPLETED=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET4_ID/no_show" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
check "No se puede marcar no_show en ticket completado (422)" "$([ "$NO_SHOW_COMPLETED" = "422" ] && echo true || echo false)"

echo ""
echo "═══ Test: no_show no afecta a tickets de pago ═══"

# Un ticket no_show no se puede marcar como pagado
NO_SHOW_PAID=$(curl -s -o /dev/null -w "%{http_code}" \
  -X PATCH "$BASE_URL/businesses/$BUSINESS_ID/tickets/$TICKET2_ID/mark_as_paid" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
check "Un ticket no_show no se puede marcar como pagado (422)" "$([ "$NO_SHOW_PAID" = "422" ] && echo true || echo false)"

echo ""
echo "═══ Test: no_show aparece en la API ═══"

# Verificar que el endpoint de tickets lista todos los estados
ALL_TICKETS=$(curl -s "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
HAS_NO_SHOW=$(echo $ALL_TICKETS | ruby -r json -e '
  j=JSON.parse(STDIN.read)
  if j.is_a?(Array)
    has_ns = j.any? { |t| t.dig("data","attributes","status") == "no_show" || (t["attributes"]||t)["status"] == "no_show" }
  elsif j["data"].is_a?(Array)
    has_ns = j["data"].any? { |t| t.dig("attributes","status") == "no_show" }
  else
    has_ns = false
  end
  puts has_ns ? "true" : "false"
' 2>/dev/null)
check "Listado de tickets incluye tickets con status no_show" "$([ "$HAS_NO_SHOW" = "true" ] && echo true || echo false)"

echo ""
echo "═══ Resumen de Tests ═══"
TOTAL=$((PASS + FAIL))
echo "Pasados: $PASS/$TOTAL"
echo "Fallados: $FAIL/$TOTAL"
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "✓ Todos los tests de no_show pasaron!"
  exit 0
else
  echo "✗ Algunos tests fallaron"
  exit 1
fi
