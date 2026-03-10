#!/bin/bash

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_URL="http://localhost:3000/api/v1"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🚀 Bokio API - Business Tests          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}\n"

# Primero hacer login para obtener el token
echo -e "${YELLOW}Obteniendo token de autenticación...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "${API_URL}/auth/sign_in" \
    -H "Content-Type: application/json" \
    -d '{
        "user": {
            "email": "admin@barberia.com",
            "password": "password123"
        }
    }')

JWT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token' 2>/dev/null)

if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" == "null" ]; then
    echo -e "${RED}❌ No se pudo obtener el token JWT${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Token obtenido${NC}\n"

# Test 1: Listar negocios
test_list_businesses() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 1: Listar negocios (GET /businesses)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 2: Ver un negocio específico
test_show_business() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 2: Ver negocio (GET /businesses/1)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/1" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 3: Crear nuevo negocio
test_create_business() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 3: Crear negocio (POST /businesses)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    TIMESTAMP=$(date +%s)
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/businesses" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"business\": {
                \"name\": \"Test Business ${TIMESTAMP}\",
                \"description\": \"Negocio de prueba creado automáticamente\",
                \"address\": \"Calle Test 123\",
                \"phone\": \"3001112233\",
                \"opening_time\": \"09:00\",
                \"closing_time\": \"18:00\"
            }
        }")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 201 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
        # Guardar ID del negocio creado
        BUSINESS_ID=$(echo "$BODY" | jq -r '.id' 2>/dev/null)
        echo "$BUSINESS_ID" > /tmp/bokio_test_business_id.txt
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 4: Actualizar negocio
test_update_business() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 4: Actualizar negocio (PATCH /businesses/:id)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ ! -f /tmp/bokio_test_business_id.txt ]; then
        echo -e "${YELLOW}⚠️  Usando ID 1 por defecto${NC}"
        BUSINESS_ID=1
    else
        BUSINESS_ID=$(cat /tmp/bokio_test_business_id.txt)
    fi
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "${API_URL}/businesses/${BUSINESS_ID}" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "business": {
                "description": "Descripción actualizada por test automatizado"
            }
        }')
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 5: Acceso sin autenticación (debe fallar)
test_unauthorized_access() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 5: Acceso sin token (debe retornar 401)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 401 ]; then
        echo -e "${GREEN}✅ Test PASSED (correctly rejected)${NC}\n"
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Ejecutar tests
test_list_businesses
test_show_business
test_create_business
test_update_business
test_unauthorized_access

# Limpiar
rm -f /tmp/bokio_test_business_id.txt

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Tests Completados              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}\n"
