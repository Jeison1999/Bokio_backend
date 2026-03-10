#!/bin/bash

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_URL="http://localhost:3000/api/v1"

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🚀 Bokio API - Tickets/Queue Tests            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}\n"

# Obtener token de autenticación (cliente)
echo -e "${YELLOW}Obteniendo token de cliente...${NC}"
CLIENT_LOGIN=$(curl -s -X POST "${API_URL}/auth/sign_in" \
    -H "Content-Type: application/json" \
    -d '{
        "user": {
            "email": "cliente@gmail.com",
            "password": "password123"
        }
    }')

CLIENT_TOKEN=$(echo "$CLIENT_LOGIN" | jq -r '.token' 2>/dev/null)

if [ -z "$CLIENT_TOKEN" ] || [ "$CLIENT_TOKEN" == "null" ]; then
    echo -e "${RED}❌ No se pudo obtener el token del cliente${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Token de cliente obtenido${NC}"

# Obtener token de admin
echo -e "${YELLOW}Obteniendo token de admin...${NC}"
ADMIN_LOGIN=$(curl -s -X POST "${API_URL}/auth/sign_in" \
    -H "Content-Type: application/json" \
    -d '{
        "user": {
            "email": "admin@barberia.com",
            "password": "password123"
        }
    }')

ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.token' 2>/dev/null)

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
    echo -e "${RED}❌ No se pudo obtener el token del admin${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Token de admin obtenido${NC}\n"

# Test 1: Listar tickets de un negocio
test_list_tickets() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 1: Listar tickets (GET /businesses/1/tickets)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/1/tickets" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response (primeros tickets):${NC}"
    echo "$BODY" | jq '.[0:2]' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 2: Ver cola de turnos activos
test_queue() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 2: Ver cola (GET /businesses/1/tickets/queue)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/1/tickets/queue" \
        -H "Authorization: Bearer ${CLIENT_TOKEN}")
    
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

# Test 3: Ver un ticket específico
test_show_ticket() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 3: Ver ticket (GET /businesses/1/tickets/1)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/1/tickets/1" \
        -H "Authorization: Bearer ${CLIENT_TOKEN}")
    
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

# Test 4: Crear nuevo ticket (cliente)
test_create_ticket() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 4: Crear ticket (POST /businesses/1/tickets)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/businesses/1/tickets" \
        -H "Authorization: Bearer ${CLIENT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "ticket": {},
            "service_ids": [1, 2]
        }')
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 201 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
        # Guardar ID del ticket creado
        TICKET_ID=$(echo "$BODY" | jq -r '.data.attributes.id' 2>/dev/null)
        echo "$TICKET_ID" > /tmp/bokio_test_ticket_id.txt
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 5: Iniciar ticket (admin)
test_start_ticket() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 5: Iniciar ticket (POST /tickets/:id/start)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Usar ticket 2 que siempre debe estar en waiting en los seeds
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/businesses/1/tickets/2/start" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "employee_id": 1
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

# Test 6: Completar ticket (admin)
test_complete_ticket() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 6: Completar ticket (POST /tickets/:id/complete)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Completar el ticket 2 que iniciamos en TEST 5
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/businesses/1/tickets/2/complete" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")
    
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

# Test 7: Cancelar ticket (cliente cancela su propio ticket)
test_cancel_ticket() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 7: Cancelar ticket propio (POST /tickets/:id/cancel)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Usar el ticket creado en TEST 4 si existe, si no usar ticket 2
    if [ -f /tmp/bokio_test_ticket_id.txt ]; then
        TICKET_ID=$(cat /tmp/bokio_test_ticket_id.txt)
    else
        TICKET_ID=2
    fi
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/businesses/1/tickets/${TICKET_ID}/cancel" \
        -H "Authorization: Bearer ${CLIENT_TOKEN}")
    
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

# Test 8: Filtrar tickets por status
test_filter_by_status() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 8: Filtrar por status (GET /tickets?status=completed)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/1/tickets?status=completed" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")
    
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

# Test 9: Acceso sin autenticación (debe fallar)
test_unauthorized_access() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 9: Acceso sin token (debe retornar 401)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/1/tickets")
    
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

# Test 10: Cliente no puede iniciar ticket de otro cliente
test_unauthorized_client() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 10: Cliente intenta iniciar ticket (debe fallar)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/businesses/1/tickets/2/start" \
        -H "Authorization: Bearer ${CLIENT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "employee_id": 1
        }')
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 403 ]; then
        echo -e "${GREEN}✅ Test PASSED (correctly rejected)${NC}\n"
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Ejecutar tests
test_list_tickets
test_queue
test_show_ticket
test_create_ticket
test_start_ticket
test_complete_ticket
test_cancel_ticket
test_filter_by_status
test_unauthorized_access
test_unauthorized_client

# Limpiar
rm -f /tmp/bokio_test_ticket_id.txt

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Tests Completados                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}\n"
