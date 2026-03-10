#!/bin/bash

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_URL="http://localhost:3000/api/v1"

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🚀 Bokio API - Employees & Services Tests     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}\n"

# Resetear base de datos con seeds
echo -e "${YELLOW}Preparando base de datos...${NC}"
bin/rails db:seed:replant > /dev/null 2>&1
echo -e "${GREEN}✅ Base de datos reseteada${NC}\n"

# Obtener token de autenticación
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

# Obtener ID del negocio dinámicamente
echo -e "${YELLOW}Obteniendo ID del negocio...${NC}"
BUSINESSES_RESPONSE=$(curl -s -X GET "${API_URL}/businesses" \
    -H "Authorization: Bearer ${JWT_TOKEN}")
BUSINESS_ID=$(echo "$BUSINESSES_RESPONSE" | jq -r '.[0].id' 2>/dev/null)

if [ -z "$BUSINESS_ID" ] || [ "$BUSINESS_ID" == "null" ]; then
    echo -e "${RED}❌ No se pudo obtener el ID del negocio${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Business ID obtenido: ${BUSINESS_ID}${NC}\n"

# ============================================
# EMPLOYEES TESTS
# ============================================

# Test 1: Listar empleados de un negocio
test_list_employees() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 1: Listar empleados (GET /businesses/${BUSINESS_ID}/employees)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/${BUSINESS_ID}/employees" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
        # Guardar ID del primer empleado para el siguiente test
        EXISTING_EMPLOYEE_ID=$(echo "$BODY" | jq -r '.[0].data.attributes.id' 2>/dev/null)
        if [ ! -z "$EXISTING_EMPLOYEE_ID" ] && [ "$EXISTING_EMPLOYEE_ID" != "null" ]; then
            echo "$EXISTING_EMPLOYEE_ID" > /tmp/bokio_test_existing_employee_id.txt
        fi
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 2: Ver un empleado específico
test_show_employee() {
    # Obtener ID del empleado existente
    if [ ! -f /tmp/bokio_test_existing_employee_id.txt ]; then
        echo -e "${YELLOW}⚠️  No se encontró ID de empleado existente, saltando test${NC}\n"
        return
    fi
    EXISTING_EMPLOYEE_ID=$(cat /tmp/bokio_test_existing_employee_id.txt)
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 2: Ver empleado (GET /businesses/${BUSINESS_ID}/employees/${EXISTING_EMPLOYEE_ID})${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/${BUSINESS_ID}/employees/${EXISTING_EMPLOYEE_ID}" \
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

# Test 3: Crear nuevo empleado
test_create_employee() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 3: Crear empleado (POST /businesses/${BUSINESS_ID}/employees)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    TIMESTAMP=$(date +%s)
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/businesses/${BUSINESS_ID}/employees" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"employee\": {
                \"name\": \"Test Employee ${TIMESTAMP}\",
                \"email\": \"test${TIMESTAMP}@barberia.com\",
                \"phone\": \"3001234567\",
                \"status\": \"available\"
            }
        }")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 201 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
        # Guardar ID del empleado creado
        EMPLOYEE_ID=$(echo "$BODY" | jq -r '.data.attributes.id' 2>/dev/null)
        echo "$EMPLOYEE_ID" > /tmp/bokio_test_employee_id.txt
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 4: Actualizar empleado
test_update_employee() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 4: Actualizar empleado (PATCH /employees/:id)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ ! -f /tmp/bokio_test_employee_id.txt ]; then
        echo -e "${YELLOW}⚠️  Usando ID 1 por defecto${NC}"
        EMPLOYEE_ID=1
    else
        EMPLOYEE_ID=$(cat /tmp/bokio_test_employee_id.txt)
    fi
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "${API_URL}/businesses/${BUSINESS_ID}/employees/${EMPLOYEE_ID}" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "employee": {
                "status": "busy"
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

# ============================================
# SERVICES TESTS
# ============================================

# Test 5: Listar servicios de un negocio
test_list_services() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 5: Listar servicios (GET /businesses/${BUSINESS_ID}/services)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/${BUSINESS_ID}/services" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
        # Guardar ID del primer servicio para el siguiente test
        EXISTING_SERVICE_ID=$(echo "$BODY" | jq -r '.[0].data.attributes.id' 2>/dev/null)
        if [ ! -z "$EXISTING_SERVICE_ID" ] && [ "$EXISTING_SERVICE_ID" != "null" ]; then
            echo "$EXISTING_SERVICE_ID" > /tmp/bokio_test_existing_service_id.txt
        fi
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 6: Ver un servicio específico
test_show_service() {
    # Obtener ID del servicio existente
    if [ ! -f /tmp/bokio_test_existing_service_id.txt ]; then
        echo -e "${YELLOW}⚠️  No se encontró ID de servicio existente, saltando test${NC}\n"
        return
    fi
    EXISTING_SERVICE_ID=$(cat /tmp/bokio_test_existing_service_id.txt)
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 6: Ver servicio (GET /businesses/${BUSINESS_ID}/services/${EXISTING_SERVICE_ID})${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/${BUSINESS_ID}/services/${EXISTING_SERVICE_ID}" \
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

# Test 7: Crear nuevo servicio
test_create_service() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 7: Crear servicio (POST /businesses/${BUSINESS_ID}/services)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/businesses/${BUSINESS_ID}/services" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "service": {
                "name": "Tinte de Cabello",
                "description": "Tinte profesional con productos de alta calidad",
                "price": 45000,
                "duration": 60,
                "active": true
            }
        }')
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo -e "\n${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo -e "\n${YELLOW}HTTP Status:${NC} $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" -eq 201 ]; then
        echo -e "${GREEN}✅ Test PASSED${NC}\n"
        # Guardar ID del servicio creado
        SERVICE_ID=$(echo "$BODY" | jq -r '.data.attributes.id' 2>/dev/null)
        echo "$SERVICE_ID" > /tmp/bokio_test_service_id.txt
    else
        echo -e "${RED}❌ Test FAILED${NC}\n"
    fi
}

# Test 8: Actualizar servicio
test_update_service() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 8: Actualizar servicio (PATCH /services/:id)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ ! -f /tmp/bokio_test_service_id.txt ]; then
        echo -e "${YELLOW}⚠️  Usando ID 1 por defecto${NC}"
        SERVICE_ID=1
    else
        SERVICE_ID=$(cat /tmp/bokio_test_service_id.txt)
    fi
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "${API_URL}/businesses/${BUSINESS_ID}/services/${SERVICE_ID}" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "service": {
                "price": 50000
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

# Test 9: Asignar servicios a empleado
test_assign_services() {
    # Verificar que tenemos IDs necesarios
    if [ ! -f /tmp/bokio_test_existing_employee_id.txt ] || [ ! -f /tmp/bokio_test_existing_service_id.txt ]; then
        echo -e "${YELLOW}⚠️  No se encontraron IDs necesarios, saltando test${NC}\n"
        return
    fi
    EXISTING_EMPLOYEE_ID=$(cat /tmp/bokio_test_existing_employee_id.txt)
    EXISTING_SERVICE_ID=$(cat /tmp/bokio_test_existing_service_id.txt)
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 9: Asignar servicios (POST /employees/${EXISTING_EMPLOYEE_ID}/assign_services)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/businesses/${BUSINESS_ID}/employees/${EXISTING_EMPLOYEE_ID}/assign_services" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"service_ids\": [${EXISTING_SERVICE_ID}]
        }")
    
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

# Test 10: Acceso sin autenticación (debe fallar)
test_unauthorized_access() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST 10: Acceso sin token (debe retornar 401)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businesses/${BUSINESS_ID}/employees")
    
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
test_list_employees
test_show_employee
test_create_employee
test_update_employee
test_list_services
test_show_service
test_create_service
test_update_service
test_assign_services
test_unauthorized_access

# Limpiar
rm -f /tmp/bokio_test_employee_id.txt
rm -f /tmp/bokio_test_service_id.txt

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Tests Completados                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}\n"
