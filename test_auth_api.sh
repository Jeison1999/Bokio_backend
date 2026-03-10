#!/bin/bash

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_URL="http://localhost:3000/api/v1"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🚀 Bokio API - Authentication Tests    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}\n"

# Función para verificar si el servidor está corriendo
check_server() {
    echo -e "${YELLOW}Verificando servidor...${NC}"
    if curl -s --max-time 2 http://localhost:3000/up > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Servidor está corriendo${NC}\n"
        return 0
    else
        echo -e "${RED}❌ Servidor NO está corriendo${NC}"
        echo -e "${YELLOW}Por favor inicia el servidor con: rails s${NC}\n"
        exit 1
    fi
}

# Test 1: Registro de nuevo usuario
test_signup() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 1: Registro de nuevo usuario (Sign Up)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Generar email único con timestamp
    TIMESTAMP=$(date +%s)
    TEST_EMAIL="test_${TIMESTAMP}@example.com"
    
    echo -e "${YELLOW}POST ${API_URL}/auth/sign_up${NC}"
    echo -e "${YELLOW}Email: ${TEST_EMAIL}${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/auth/sign_up" \
        -H "Content-Type: application/json" \
        -d "{
            \"user\": {
                \"email\": \"${TEST_EMAIL}\",
                \"password\": \"password123\",
                \"password_confirmation\": \"password123\",
                \"name\": \"Usuario Test\",
                \"phone\": \"3001234567\",
                \"role\": \"client\"
            }
        }")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 201 ] || [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 2: Login (Sign In)
test_signin() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 2: Login de usuario (Sign In)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${YELLOW}POST ${API_URL}/auth/sign_in${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/auth/sign_in" \
        -H "Content-Type: application/json" \
        -d '{
            "user": {
                "email": "cliente@gmail.com",
                "password": "password123"
            }
        }')
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    # Extraer el token JWT del JSON response
    JWT_TOKEN=$(echo "$BODY" | jq -r '.token' 2>/dev/null)
    
    echo -e "\n${YELLOW}Response Body:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    
    if [ ! -z "$JWT_TOKEN" ] && [ "$JWT_TOKEN" != "null" ]; then
        echo -e "\n${GREEN}✅ JWT Token recibido:${NC}"
        echo -e "${YELLOW}${JWT_TOKEN:0:50}...${NC}"
        # Guardar token para próximos tests
        echo "$JWT_TOKEN" > /tmp/bokio_jwt_token.txt
    fi
    
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 200 ] && [ ! -z "$JWT_TOKEN" ] && [ "$JWT_TOKEN" != "null" ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
        return 0
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
        return 1
    fi
}

# Test 3: Login con usuario existente de seeds
test_signin_seeded_user() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 3: Login con usuario Admin (seeds)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${YELLOW}POST ${API_URL}/auth/sign_in${NC}"
    echo -e "${YELLOW}Email: admin@barberia.com${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/auth/sign_in" \
        -H "Content-Type: application/json" \
        -d '{
            "user": {
                "email": "admin@barberia.com",
                "password": "password123"
            }
        }')
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    JWT_TOKEN=$(echo "$BODY" | jq -r '.token' 2>/dev/null)
    
    echo -e "\n${YELLOW}Response Body:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 4: Logout (Sign Out)
test_signout() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 4: Logout de usuario (Sign Out)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ ! -f /tmp/bokio_jwt_token.txt ]; then
        echo -e "${RED}❌ No JWT token found. Skipping test.${NC}\n"
        return
    fi
    
    JWT_TOKEN=$(cat /tmp/bokio_jwt_token.txt)
    
    echo -e "${YELLOW}DELETE ${API_URL}/auth/sign_out${NC}"
    echo -e "${YELLOW}Using JWT Token${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${API_URL}/auth/sign_out" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
    else
        echo -e "${RED}⚠️  Test status: $HTTP_STATUS${NC}\n"
    fi
    
    # Limpiar token
    rm -f /tmp/bokio_jwt_token.txt
}

# Test 5: Login inválido
test_invalid_login() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 5: Login con credenciales inválidas${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${YELLOW}POST ${API_URL}/auth/sign_in${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/auth/sign_in" \
        -H "Content-Type: application/json" \
        -d '{
            "user": {
                "email": "invalid@example.com",
                "password": "wrongpassword"
            }
        }')
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 401 ]; then
        echo -e "${GREEN}✅ Test PASSED (correctly rejected)${NC}\n"
    else
        echo -e "${RED}❌ Test FAILED (should return 401)${NC}\n"
    fi
}

# Ejecutar tests
check_server
test_signup
test_signin
test_signin_seeded_user
test_signout
test_invalid_login

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Tests Completados              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}\n"
