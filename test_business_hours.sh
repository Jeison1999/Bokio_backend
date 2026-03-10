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
BUSINESS_ID=$(curl -s "$BASE_URL/businesses" -H "Authorization: Bearer $ADMIN_TOKEN" \
  | ruby -r json -e 'j=JSON.parse(STDIN.read); d=j.is_a?(Array) ? j : j["data"]; puts d[0]["id"]')
echo "✓ Admin autenticado (Business ID: $BUSINESS_ID)"

CLIENT=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"cliente@gmail.com","password":"password123"}}')
CLIENT_TOKEN=$(echo $CLIENT | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.dig("data","token") || j["token"] || ""')
echo "✓ Cliente autenticado"

echo ""
echo "═══ Test: Negocio abierto (horario que cubre la hora actual) ═══"

# Primero ponemos horario 00:00-23:59 para garantizar que está abierto
curl -s -o /dev/null -X PATCH "$BASE_URL/businesses/$BUSINESS_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"business":{"opening_time":"00:00","closing_time":"23:59","break_start_time":null,"break_end_time":null}}'

TICKET_RESP=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -d '{"ticket":{}}')
TICKET_STATUS=$(echo $TICKET_RESP | ruby -r json -e '
  j=JSON.parse(STDIN.read)
  t=j["data"]||j
  a=t["attributes"]||t
  puts a["status"]
' 2>/dev/null)
TICKET_ID=$(echo $TICKET_RESP | ruby -r json -e '
  j=JSON.parse(STDIN.read)
  t=j["data"]||j
  puts t["id"] || ""
' 2>/dev/null)
check "Se puede crear ticket cuando el negocio está abierto" "$([ "$TICKET_STATUS" = "waiting" ] && echo true || echo false)"

echo ""
echo "═══ Test: Negocio cerrado (horario pasado) ═══"

# Actualizar negocio con horario ya pasado (00:01 - 00:02) para simular cerrado
UPDATE_RESP=$(curl -s -o /dev/null -w "%{http_code}" \
  -X PATCH "$BASE_URL/businesses/$BUSINESS_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"business":{"opening_time":"00:01","closing_time":"00:02"}}')
check "Admin puede actualizar horario del negocio (200)" "$([ "$UPDATE_RESP" = "200" ] && echo true || echo false)"

# Intentar crear ticket con negocio cerrado
CLOSED_RESP=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -d '{"ticket":{}}')
CLOSED_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -d '{"ticket":{}}')
check "No se puede crear ticket cuando el negocio está cerrado (422)" "$([ "$CLOSED_STATUS" = "422" ] && echo true || echo false)"

# Verificar que devuelve mensaje de error
ERROR_MSG=$(echo $CLOSED_RESP | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j["error"] || ""' 2>/dev/null)
check "Respuesta incluye mensaje de error descriptivo" "$([ -n "$ERROR_MSG" ] && echo true || echo false)"
echo "  Mensaje: $ERROR_MSG"

echo ""
echo "═══ Test: Negocio en descanso ═══"

# Configurar horario de descanso que cubra la hora actual
# Usamos un rango amplio para el break (00:00 - 23:59)
# y horario de apertura amplio (00:00 - 23:59)
BREAK_UPDATE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X PATCH "$BASE_URL/businesses/$BUSINESS_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"business":{"opening_time":"00:00","closing_time":"23:59","break_start_time":"00:00","break_end_time":"23:58"}}')
check "Admin puede configurar horario de descanso (200)" "$([ "$BREAK_UPDATE" = "200" ] && echo true || echo false)"

BREAK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -d '{"ticket":{}}')
check "No se puede crear ticket durante el descanso (422)" "$([ "$BREAK_STATUS" = "422" ] && echo true || echo false)"

BREAK_MSG=$(curl -s -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -d '{"ticket":{}}' | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j["error"] || ""' 2>/dev/null)
check "Mensaje de descanso es descriptivo" "$(echo "$BREAK_MSG" | grep -qi "break" && echo true || echo false)"
echo "  Mensaje: $BREAK_MSG"

echo ""
echo "═══ Test: Negocio sin horario definido (siempre abierto) ═══"

# Negocio sin opening_time ni closing_time = siempre disponible
NO_HOURS_UPDATE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X PATCH "$BASE_URL/businesses/$BUSINESS_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"business":{"opening_time":null,"closing_time":null,"break_start_time":null,"break_end_time":null}}')
check "Admin puede quitar horario del negocio (200)" "$([ "$NO_HOURS_UPDATE" = "200" ] && echo true || echo false)"

NO_HOURS_TICKET=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$BASE_URL/businesses/$BUSINESS_ID/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -d '{"ticket":{}}')
check "Se puede crear ticket en negocio sin horario definido (201)" "$([ "$NO_HOURS_TICKET" = "201" ] && echo true || echo false)"

echo ""
echo "═══ Resumen de Tests ═══"
TOTAL=$((PASS + FAIL))
echo "Pasados: $PASS/$TOTAL"
echo "Fallados: $FAIL/$TOTAL"
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "✓ Todos los tests de horario pasaron!"
  exit 0
else
  echo "✗ Algunos tests fallaron"
  exit 1
fi
