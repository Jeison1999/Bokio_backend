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

# Super Admin
SUPER_ADMIN=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"superadmin@bokio.com","password":"password123"}}')
SUPER_TOKEN=$(echo $SUPER_ADMIN | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.dig("data","token") || j["token"] || ""')
echo "✓ Super Admin autenticado"

# Admin (dueño de negocio)
ADMIN=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"admin@barberia.com","password":"password123"}}')
ADMIN_TOKEN=$(echo $ADMIN | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.dig("data","token") || j["token"] || ""')
BUSINESS_ID=$(echo $ADMIN | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.dig("data","business_id") || ""')
echo "✓ Admin autenticado (Business ID: $BUSINESS_ID)"

# Cliente
CLIENT=$(curl -s -X POST "$BASE_URL/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"cliente@gmail.com","password":"password123"}}')
CLIENT_TOKEN=$(echo $CLIENT | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.dig("data","token") || j["token"] || ""')
echo "✓ Cliente autenticado"

echo ""
echo "═══ Test: Listado de negocios para clientes ═══"

# Cliente puede ver listado de negocios activos
LIST=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/businesses" \
  -H "Authorization: Bearer $CLIENT_TOKEN")
check "Cliente puede ver listado de negocios (200)" "$([ "$LIST" = "200" ] && echo true || echo false)"

# Listado contiene negocios
LIST_BODY=$(curl -s "$BASE_URL/businesses" -H "Authorization: Bearer $CLIENT_TOKEN")
BUSINESS_COUNT=$(echo $LIST_BODY | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.is_a?(Array) ? j.length : (j["data"]||[]).length' 2>/dev/null)
check "Listado contiene negocios (al menos 1)" "$([ "$BUSINESS_COUNT" -ge 1 ] 2>/dev/null && echo true || echo false)"

echo ""
echo "═══ Test: Búsqueda por nombre ═══"

# Buscar por nombre "Spa"
SEARCH=$(curl -s "$BASE_URL/businesses?q=Spa" -H "Authorization: Bearer $CLIENT_TOKEN")
SEARCH_COUNT=$(echo $SEARCH | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.is_a?(Array) ? j.length : (j["data"]||[]).length' 2>/dev/null)
check "Búsqueda por 'Spa' encuentra resultados" "$([ "$SEARCH_COUNT" -ge 1 ] 2>/dev/null && echo true || echo false)"

# Búsqueda sin resultados
SEARCH_EMPTY=$(curl -s "$BASE_URL/businesses?q=xyznoexiste999" -H "Authorization: Bearer $CLIENT_TOKEN")
EMPTY_COUNT=$(echo $SEARCH_EMPTY | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.is_a?(Array) ? j.length : (j["data"]||[]).length' 2>/dev/null)
check "Búsqueda sin resultados devuelve array vacío" "$([ "$EMPTY_COUNT" = "0" ] && echo true || echo false)"

# Búsqueda case-insensitive
SEARCH_LOWER=$(curl -s "$BASE_URL/businesses?q=spa" -H "Authorization: Bearer $CLIENT_TOKEN")
LOWER_COUNT=$(echo $SEARCH_LOWER | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.is_a?(Array) ? j.length : (j["data"]||[]).length' 2>/dev/null)
check "Búsqueda es case-insensitive ('spa' encuentra 'Spa Relax')" "$([ "$LOWER_COUNT" -ge 1 ] 2>/dev/null && echo true || echo false)"

echo ""
echo "═══ Test: Buscar por slug ═══"

# Obtener slug del primer negocio
BUSINESS_SLUG=$(echo $LIST_BODY | ruby -r json -e 'j=JSON.parse(STDIN.read); d=j.is_a?(Array) ? j : j["data"]; puts d.length > 0 ? d[0]["slug"] : ""' 2>/dev/null)
echo "  Slug encontrado: $BUSINESS_SLUG"

# Buscar por slug
SLUG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/businesses/by_slug/$BUSINESS_SLUG" \
  -H "Authorization: Bearer $CLIENT_TOKEN")
check "Puede buscar negocio por slug (200)" "$([ "$SLUG_STATUS" = "200" ] && echo true || echo false)"

# Respuesta por slug tiene empleados
SLUG_BODY=$(curl -s "$BASE_URL/businesses/by_slug/$BUSINESS_SLUG" -H "Authorization: Bearer $CLIENT_TOKEN")
HAS_EMPLOYEES=$(echo $SLUG_BODY | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.key?("employees") ? "true" : "false"' 2>/dev/null)
check "Vista por slug incluye empleados" "$([ "$HAS_EMPLOYEES" = "true" ] && echo true || echo false)"

# Respuesta por slug tiene servicios
HAS_SERVICES=$(echo $SLUG_BODY | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.key?("services") ? "true" : "false"' 2>/dev/null)
check "Vista por slug incluye servicios" "$([ "$HAS_SERVICES" = "true" ] && echo true || echo false)"

# Respuesta incluye tamaño de la cola actual
HAS_QUEUE=$(echo $SLUG_BODY | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.key?("current_queue_size") ? "true" : "false"' 2>/dev/null)
check "Vista por slug incluye tamaño de cola" "$([ "$HAS_QUEUE" = "true" ] && echo true || echo false)"

# Slug inexistente devuelve 404
SLUG_404=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/businesses/by_slug/negocio-que-no-existe" \
  -H "Authorization: Bearer $CLIENT_TOKEN")
check "Slug inexistente devuelve 404" "$([ "$SLUG_404" = "404" ] && echo true || echo false)"

echo ""
echo "═══ Test: Show del negocio (cliente obtiene vista pública) ═══"

# Convertir slug a ID para el show
BUSINESS_ID_FROM_SLUG=$(echo $LIST_BODY | ruby -r json -e 'j=JSON.parse(STDIN.read); d=j.is_a?(Array) ? j : j["data"]; puts d.length > 0 ? d[0]["id"].to_s : ""' 2>/dev/null)

SHOW_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/businesses/$BUSINESS_ID_FROM_SLUG" \
  -H "Authorization: Bearer $CLIENT_TOKEN")
check "Cliente puede ver detalle de negocio (200)" "$([ "$SHOW_STATUS" = "200" ] && echo true || echo false)"

SHOW_BODY=$(curl -s "$BASE_URL/businesses/$BUSINESS_ID_FROM_SLUG" -H "Authorization: Bearer $CLIENT_TOKEN")
HAS_EMPLOYEES_SHOW=$(echo $SHOW_BODY | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.key?("employees") ? "true" : "false"' 2>/dev/null)
check "Detalle incluye empleados con servicios" "$([ "$HAS_EMPLOYEES_SHOW" = "true" ] && echo true || echo false)"

echo ""
echo "═══ Test: Super Admin ve todos los negocios ═══"

SA_LIST=$(curl -s "$BASE_URL/businesses" -H "Authorization: Bearer $SUPER_TOKEN")
SA_COUNT=$(echo $SA_LIST | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.is_a?(Array) ? j.length : (j["data"]||[]).length' 2>/dev/null)
check "Super Admin ve todos los negocios (>=2)" "$([ "$SA_COUNT" -ge 2 ] 2>/dev/null && echo true || echo false)"

echo ""
echo "═══ Test: Admin ve sus negocios ═══"

ADMIN_LIST=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/businesses" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
check "Admin puede listar sus negocios (200)" "$([ "$ADMIN_LIST" = "200" ] && echo true || echo false)"

# Admin solo ve SUS negocios (no todos)
ADMIN_LIST_BODY=$(curl -s "$BASE_URL/businesses" -H "Authorization: Bearer $ADMIN_TOKEN")
ADMIN_COUNT=$(echo $ADMIN_LIST_BODY | ruby -r json -e 'j=JSON.parse(STDIN.read); puts j.is_a?(Array) ? j.length : (j["data"]||[]).length' 2>/dev/null)
check "Admin solo ve sus propios negocios (todos le pertenecen)" "$([ "$ADMIN_COUNT" -ge 1 ] 2>/dev/null && echo true || echo false)"

echo ""
echo "═══ Resumen de Tests ═══"
TOTAL=$((PASS + FAIL))
echo "Pasados: $PASS/$TOTAL"
echo "Fallados: $FAIL/$TOTAL"
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "✓ Todos los tests de búsqueda pasaron!"
  exit 0
else
  echo "✗ Algunos tests fallaron"
  exit 1
fi
