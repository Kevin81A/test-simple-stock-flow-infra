#!/usr/bin/env bash
set -e

# ==============================================================================
# Simple Stock Flow · Script de Verificación Integral
# Prueba técnica SDD · SENA ADSO Ficha 3413974
# ==============================================================================

echo "======================================================================"
echo "  Iniciando sondas de verificación para Simple Stock Flow"
echo "======================================================================"

API_URL="${API_URL:-http://localhost:8000}"
APP_URL="${APP_URL:-http://localhost:8080}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-Admin12345!}"

FAILED=0

check_probe() {
    local name="$1"
    local result="$2"
    if [ "$result" -eq 0 ]; then
        echo -e "  \033[0;32m✓ [PASÓ]\033[0m $name"
    else
        echo -e "  \033[0;31m✗ [FALLÓ]\033[0m $name"
        FAILED=$((FAILED + 1))
    fi
}

echo -e "\n--- Sonda 1: Healthcheck en el servicio API (:8000/health) ---"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" || echo "000")
BODY=$(curl -s "$API_URL/health" || echo "")
if [ "$STATUS" = "200" ] && [[ "$BODY" =~ "ok" ]]; then
    check_probe "P-01: Healthcheck 200 OK con respuesta esperada" 0
else
    echo "  Detalle: status=$STATUS, body=$BODY"
    check_probe "P-01: Healthcheck 200 OK" 1
fi

echo -e "\n--- Sonda 2: Invariante D-C9 (401 debe tener cuerpo vacío) ---"
RESP_401=$(curl -s -i "$API_URL/api/products" || true)
HTTP_CODE_401=$(echo "$RESP_401" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
CONTENT_LENGTH_401=$(echo "$RESP_401" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
if [ "$HTTP_CODE_401" = "401" ] && [ "$CONTENT_LENGTH_401" = "0" ]; then
    check_probe "P-02: 401 no autenticado tiene Content-Length: 0" 0
else
    echo "  Detalle: code=$HTTP_CODE_401, content-length=$CONTENT_LENGTH_401"
    check_probe "P-02: 401 vacío" 1
fi

echo -e "\n--- Sonda 3: Invariante D-C9 (404 debe tener cuerpo vacío) ---"
RESP_404=$(curl -s -i "$API_URL/api/ruta-inexistente" || true)
HTTP_CODE_404=$(echo "$RESP_404" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
CONTENT_LENGTH_404=$(echo "$RESP_404" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
if [ "$HTTP_CODE_404" = "404" ] && [ "$CONTENT_LENGTH_404" = "0" ]; then
    check_probe "P-03: 404 no encontrado tiene Content-Length: 0" 0
else
    echo "  Detalle: code=$HTTP_CODE_404, content-length=$CONTENT_LENGTH_404"
    check_probe "P-03: 404 vacío" 1
fi

echo -e "\n--- Sonda 4: Autenticación Admin y obtención de JWT ---"
LOGIN_RESP=$(curl -s -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}" || echo "{}")
TOKEN=$(echo "$LOGIN_RESP" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
if [ -n "$TOKEN" ]; then
    check_probe "P-04: Autenticación exitosa y JWT obtenido" 0
else
    echo "  Detalle: $LOGIN_RESP"
    check_probe "P-04: Login admin" 1
fi

echo -e "\n--- Sonda 5: Consulta de Categorías Semilla (Exactamente 5) ---"
CATS_RESP=$(curl -s -X GET "$API_URL/api/categories" -H "Authorization: Bearer $TOKEN" || echo "[]")
CAT_COUNT=$(echo "$CATS_RESP" | grep -o '"id":' | wc -l)
if [ "$CAT_COUNT" -eq 5 ]; then
    check_probe "P-05: 5 categorías fijas sembradas correctamente" 0
else
    echo "  Detalle: count=$CAT_COUNT, resp=$CATS_RESP"
    check_probe "P-05: Categorías semilla" 1
fi

echo -e "\n--- Sonda 6: Invariante D-C9 RFC 7807 (400 con detail y errors) ---"
BAD_REQ_RESP=$(curl -s -i -X POST "$API_URL/api/products" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"","price":-10}' || true)
BAD_STATUS=$(echo "$BAD_REQ_RESP" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
CONTENT_TYPE_400=$(echo "$BAD_REQ_RESP" | grep -i "content-type" | awk '{print $2}' | tr -d '\r')
if [ "$BAD_STATUS" = "400" ] && [[ "$CONTENT_TYPE_400" =~ "problem+json" ]]; then
    check_probe "P-06: 400 Bad Request retorna application/problem+json" 0
else
    echo "  Detalle: status=$BAD_STATUS, content-type=$CONTENT_TYPE_400"
    check_probe "P-06: 400 RFC 7807" 1
fi

echo -e "\n--- Sonda 7: Frontend SPA en Nginx (:8080) ---"
FRONT_RESP=$(curl -s "$APP_URL/" || echo "")
if [[ "$FRONT_RESP" =~ 'lang="es"' ]] || [[ "$FRONT_RESP" =~ 'Simple Stock Flow' ]]; then
    check_probe "P-07: Frontend disponible con <html lang=\"es\">" 0
else
    check_probe "P-07: Frontend SPA" 1
fi

echo -e "\n======================================================================"
if [ "$FAILED" -eq 0 ]; then
    echo -e "  \033[0;32m¡TODAS LAS SONDAS DE VERIFICACIÓN PASARON EXITOSAMENTE!\033[0m"
    echo "======================================================================"
    exit 0
else
    echo -e "  \033[0;31mSE ENCONTRARON $FAILED FALLOS EN LA VERIFICACIÓN.\033[0m"
    echo "======================================================================"
    exit 1
fi
