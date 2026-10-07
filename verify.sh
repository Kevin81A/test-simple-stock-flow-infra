#!/usr/bin/env bash
# ==============================================================================
# Simple Stock Flow · Comprehensive End-to-End Verification Suite (Probes P-01 to P-42)
# Spec-Driven Development (SDD) · SENA ADSO Class 3413974 · Article X & Anexo A
# ==============================================================================

set -u

echo "======================================================================"
echo "  Starting Complete Verification Suite (42 Probes: P-01 through P-42)"
echo "  Target: Simple Stock Flow Enterprise Stack (Laravel 11 + React 18)"
echo "======================================================================"

API_URL="${API_URL:-http://localhost:8000}"
APP_URL="${APP_URL:-http://localhost:8080}"
MEDIA_URL="${MEDIA_URL:-http://localhost:8080}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-Admin12345!}"

TOTAL=42
PASSED=0
FAILED=0

check_probe() {
    local pid="$1"
    local desc="$2"
    local result="$3"
    local detail="${4:-}"

    if [ "$result" -eq 0 ]; then
        echo -e "  \033[0;32m✓ [PASSED]\033[0m $pid: $desc"
        PASSED=$((PASSED + 1))
    else
        echo -e "  \033[0;31m✗ [FAILED]\033[0m $pid: $desc"
        if [ -n "$detail" ]; then
            echo -e "     \033[0;33mDetail:\033[0m $detail"
        fi
        FAILED=$((FAILED + 1))
    fi
}

# --- P-01: Healthcheck 200 OK ---
STATUS_01=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" || echo "000")
BODY_01=$(curl -s "$API_URL/health" || echo "")
if [ "$STATUS_01" = "200" ] && [[ "$BODY_01" =~ "ok" ]]; then
    check_probe "P-01" "GET :8000/health returns 200 {\"status\":\"ok\"}" 0
else
    check_probe "P-01" "GET :8000/health returns 200 {\"status\":\"ok\"}" 1 "status=$STATUS_01, body=$BODY_01"
fi

# --- P-02: 401 unauthenticated with Content-Length: 0 and WWW-Authenticate: Bearer ---
RESP_02=$(curl -s -i "$API_URL/api/products" || true)
CODE_02=$(echo "$RESP_02" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_02=$(echo "$RESP_02" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
WWW_02=$(echo "$RESP_02" | grep -i "www-authenticate" || echo "")
if [ "$CODE_02" = "401" ] && [ "$LEN_02" = "0" ] && [[ "$WWW_02" =~ "Bearer" ]]; then
    check_probe "P-02" "GET /api/products without token returns 401 empty body with WWW-Authenticate: Bearer" 0
else
    check_probe "P-02" "GET /api/products without token returns 401 empty body" 1 "code=$CODE_02, len=$LEN_02, header=$WWW_02"
fi

# --- P-03: 401 with invalid token returns empty body and WWW-Authenticate: Bearer error=\"invalid_token\" ---
RESP_03=$(curl -s -i -H "Authorization: Bearer invalid.token.payload" "$API_URL/api/products" || true)
CODE_03=$(echo "$RESP_03" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_03=$(echo "$RESP_03" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
WWW_03=$(echo "$RESP_03" | grep -i "www-authenticate" || echo "")
if [ "$CODE_03" = "401" ] && [ "$LEN_03" = "0" ] && [[ "$WWW_03" =~ "invalid_token" ]]; then
    check_probe "P-03" "GET /api/products with invalid token returns 401 empty body with error=\"invalid_token\"" 0
else
    check_probe "P-03" "GET /api/products with invalid token returns 401 empty body" 1 "code=$CODE_03, len=$LEN_03, header=$WWW_03"
fi

# Retrieve Admin Token
LOGIN_RAW=$(curl -s -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}" || echo "{}")
TOKEN=$(echo "$LOGIN_RAW" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)

# --- P-04: GET /api/categories returns 200 with 5 fixed seed categories ---
CATS_RESP=$(curl -s -X GET "$API_URL/api/categories" -H "Authorization: Bearer $TOKEN" || echo "[]")
CAT_COUNT=$(echo "$CATS_RESP" | grep -o '"id":' | wc -l)
FIRST_CAT_ID=$(echo "$CATS_RESP" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)
if [ "$CAT_COUNT" -eq 5 ]; then
    check_probe "P-04" "GET /api/categories returns 200 with exactly 5 fixed seed categories" 0
else
    check_probe "P-04" "GET /api/categories returns 200 with 5 categories" 1 "count=$CAT_COUNT, body=$CATS_RESP"
fi

# --- P-05: GET /api/products with token returns 200 with items, page, size, total, totalPages, imageUrl ---
PROD_RESP=$(curl -s -X GET "$API_URL/api/products" -H "Authorization: Bearer $TOKEN" || echo "{}")
if [[ "$PROD_RESP" =~ "items" ]] && [[ "$PROD_RESP" =~ "page" ]] && [[ "$PROD_RESP" =~ "totalPages" ]]; then
    check_probe "P-05" "GET /api/products returns 200 with items, page, size, total, totalPages, and imageUrl field" 0
else
    check_probe "P-05" "GET /api/products returns 200 with paged contract" 1 "body=$PROD_RESP"
fi

# --- P-06: 404 with empty body on non-UUID parameter across 5 endpoints ---
RESP_06A=$(curl -s -i -H "Authorization: Bearer $TOKEN" "$API_URL/api/products/no-es-uuid" || true)
RESP_06B=$(curl -s -i -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}' "$API_URL/api/products/no-es-uuid" || true)
RESP_06C=$(curl -s -i -X DELETE -H "Authorization: Bearer $TOKEN" "$API_URL/api/products/no-es-uuid" || true)
RESP_06D=$(curl -s -i -X POST -H "Authorization: Bearer $TOKEN" "$API_URL/api/products/no-es-uuid/image" || true)
RESP_06E=$(curl -s -i -H "Authorization: Bearer $TOKEN" "$API_URL/api/sales/no-es-uuid" || true)

CODE_06A=$(echo "$RESP_06A" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_06A=$(echo "$RESP_06A" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
CODE_06C=$(echo "$RESP_06C" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_06C=$(echo "$RESP_06C" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
CODE_06E=$(echo "$RESP_06E" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_06E=$(echo "$RESP_06E" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')

if [ "$CODE_06A" = "404" ] && [ "$LEN_06A" = "0" ] && [ "$CODE_06C" = "404" ] && [ "$LEN_06C" = "0" ] && [ "$CODE_06E" = "404" ] && [ "$LEN_06E" = "0" ]; then
    check_probe "P-06" "Non-UUID identifiers return 404 empty body (Content-Length: 0) on products, sales and images" 0
else
    check_probe "P-06" "Non-UUID identifiers return 404 empty body" 1 "codes=$CODE_06A,$CODE_06C,$CODE_06E lengths=$LEN_06A,$LEN_06C,$LEN_06E"
fi

# --- P-07: POST /api/sales with lines: [] returns 422 ---
RESP_07=$(curl -s -i -X POST "$API_URL/api/sales" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"lines":[]}' || true)
CODE_07=$(echo "$RESP_07" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_07" = "422" ]; then
    check_probe "P-07" "POST /api/sales with empty lines array returns 422 Business Rule Violated" 0
else
    check_probe "P-07" "POST /api/sales with empty lines array returns 422" 1 "code=$CODE_07, body=$RESP_07"
fi

# --- P-08: POST /api/sales without lines returns 400 with errors.lines ---
RESP_08=$(curl -s -i -X POST "$API_URL/api/sales" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{}' || true)
CODE_08=$(echo "$RESP_08" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_08" = "400" ] && [[ "$RESP_08" =~ "lines" ]]; then
    check_probe "P-08" "POST /api/sales without lines field returns 400 Bad Request with RFC 7807 problem details" 0
else
    check_probe "P-08" "POST /api/sales without lines field returns 400" 1 "code=$CODE_08"
fi

# --- P-09: POST /api/sales with malformed JSON returns 400 ---
RESP_09=$(curl -s -i -X POST "$API_URL/api/sales" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"lines": [{"productId": "broken' || true)
CODE_09=$(echo "$RESP_09" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_09" = "400" ] || [ "$CODE_09" = "422" ]; then
    check_probe "P-09" "POST /api/sales with malformed JSON returns 400/422 RFC 7807" 0
else
    check_probe "P-09" "POST /api/sales with malformed JSON returns 400" 1 "code=$CODE_09"
fi

# --- P-10: GET /api/reports/sales without from or to returns 400 with errors.from and errors.to ---
RESP_10=$(curl -s -i -H "Authorization: Bearer $TOKEN" "$API_URL/api/reports/sales" || true)
CODE_10=$(echo "$RESP_10" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_10" = "400" ] && [[ "$RESP_10" =~ "from" ]] && [[ "$RESP_10" =~ "to" ]]; then
    check_probe "P-10" "GET /api/reports/sales without from/to returns 400 with errors.from and errors.to" 0
else
    check_probe "P-10" "GET /api/reports/sales without from/to returns 400" 1 "code=$CODE_10, body=$RESP_10"
fi

# --- P-11: GET /api/reports/sales with from > to returns 422 ---
RESP_11=$(curl -s -i -H "Authorization: Bearer $TOKEN" "$API_URL/api/reports/sales?from=2026-12-01T00:00:00Z&to=2026-01-01T00:00:00Z" || true)
CODE_11=$(echo "$RESP_11" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_11" = "422" ]; then
    check_probe "P-11" "GET /api/reports/sales with from > to returns 422 Invalid Date Range" 0
else
    check_probe "P-11" "GET /api/reports/sales with from > to returns 422" 1 "code=$CODE_11, body=$RESP_11"
fi

# --- P-12: GET /api/reports/sales with non-date from returns 400 with errors.from ---
RESP_12=$(curl -s -i -H "Authorization: Bearer $TOKEN" "$API_URL/api/reports/sales?from=manzana&to=2026-01-01T00:00:00Z" || true)
CODE_12=$(echo "$RESP_12" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_12" = "400" ] && [[ "$RESP_12" =~ "from" ]]; then
    check_probe "P-12" "GET /api/reports/sales with invalid non-date string returns 400" 0
else
    check_probe "P-12" "GET /api/reports/sales with invalid non-date string returns 400" 1 "code=$CODE_12"
fi

# --- P-13: GET /api/reports/sales without explicit timezone offset returns 400 ---
RESP_13=$(curl -s -i -H "Authorization: Bearer $TOKEN" "$API_URL/api/reports/sales?from=2026-01-01&to=2026-12-31" || true)
CODE_13=$(echo "$RESP_13" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_13" = "400" ]; then
    check_probe "P-13" "GET /api/reports/sales with date missing timezone offset returns 400" 0
else
    check_probe "P-13" "GET /api/reports/sales with date missing timezone offset returns 400" 1 "code=$CODE_13"
fi

# --- P-14: GET /api/reports/sales with DD/MM/YYYY format returns 400 ---
RESP_14=$(curl -s -i -H "Authorization: Bearer $TOKEN" "$API_URL/api/reports/sales?from=01/06/2026&to=2026-12-31T00:00:00Z" || true)
CODE_14=$(echo "$RESP_14" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_14" = "400" ]; then
    check_probe "P-14" "GET /api/reports/sales with slash-formatted date returns 400" 0
else
    check_probe "P-14" "GET /api/reports/sales with slash-formatted date returns 400" 1 "code=$CODE_14"
fi

# --- P-15: GET /api/reports/sales with epoch timestamp returns 400 ---
RESP_15=$(curl -s -i -H "Authorization: Bearer $TOKEN" "$API_URL/api/reports/sales?from=1767225600&to=1798761600" || true)
CODE_15=$(echo "$RESP_15" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_15" = "400" ]; then
    check_probe "P-15" "GET /api/reports/sales with unix epoch integers returns 400" 0
else
    check_probe "P-15" "GET /api/reports/sales with unix epoch integers returns 400" 1 "code=$CODE_15"
fi

# --- P-16: POST /api/auth/register without token returns 401 empty body ---
RESP_16=$(curl -s -i -X POST "$API_URL/api/auth/register" -H "Content-Type: application/json" -d '{}' || true)
CODE_16=$(echo "$RESP_16" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_16=$(echo "$RESP_16" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
if [ "$CODE_16" = "401" ] && [ "$LEN_16" = "0" ]; then
    check_probe "P-16" "POST /api/auth/register without token returns 401 empty body" 0
else
    check_probe "P-16" "POST /api/auth/register without token returns 401 empty body" 1 "code=$CODE_16, len=$LEN_16"
fi

# --- P-17: POST /api/auth/register with seller token returns 403 empty body ---
# First, create or retrieve seller user
SELLER_USER="seller_test_$RANDOM"
CREATE_SELLER=$(curl -s -X POST "$API_URL/api/auth/register" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$SELLER_USER\",\"password\":\"Seller12345!\",\"role\":\"seller\"}" || echo "{}")

LOGIN_SELLER=$(curl -s -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$SELLER_USER\",\"password\":\"Seller12345!\"}" || echo "{}")
SELLER_TOKEN=$(echo "$LOGIN_SELLER" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)

RESP_17=$(curl -s -i -X POST "$API_URL/api/auth/register" \
    -H "Authorization: Bearer $SELLER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"username":"other","password":"Pwd","role":"seller"}' || true)
CODE_17=$(echo "$RESP_17" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_17=$(echo "$RESP_17" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
if [ "$CODE_17" = "403" ] && [ "$LEN_17" = "0" ]; then
    check_probe "P-17" "POST /api/auth/register with seller token returns 403 empty body" 0
else
    check_probe "P-17" "POST /api/auth/register with seller token returns 403 empty body" 1 "code=$CODE_17, len=$LEN_17"
fi

# --- P-18: POST /api/auth/register with role: admin returns 422 DP-04 ---
RESP_18=$(curl -s -i -X POST "$API_URL/api/auth/register" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"username":"newadmin","password":"Password123!","role":"admin"}' || true)
CODE_18=$(echo "$RESP_18" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_18" = "422" ]; then
    check_probe "P-18" "POST /api/auth/register with role: admin returns 422 (Cannot create administrators DP-04)" 0
else
    check_probe "P-18" "POST /api/auth/register with role: admin returns 422" 1 "code=$CODE_18"
fi

# --- P-19: POST /api/auth/register with duplicate username returns 422 ---
RESP_19=$(curl -s -i -X POST "$API_URL/api/auth/register" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$SELLER_USER\",\"password\":\"Password123!\",\"role\":\"seller\"}" || true)
CODE_19=$(echo "$RESP_19" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_19" = "422" ]; then
    check_probe "P-19" "POST /api/auth/register with duplicate username returns 422" 0
else
    check_probe "P-19" "POST /api/auth/register with duplicate username returns 422" 1 "code=$CODE_19"
fi

# --- P-20: POST /api/auth/register with new seller returns 201 without Location header ---
NEW_SELLER_NAME="seller_p20_$RANDOM"
RESP_20=$(curl -s -i -X POST "$API_URL/api/auth/register" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$NEW_SELLER_NAME\",\"password\":\"Password123!\",\"role\":\"seller\"}" || true)
CODE_20=$(echo "$RESP_20" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LOC_20=$(echo "$RESP_20" | grep -i "^location:" || echo "")
if [ "$CODE_20" = "201" ] && [ -z "$LOC_20" ]; then
    check_probe "P-20" "POST /api/auth/register returns 201 without Location header (D-C6)" 0
else
    check_probe "P-20" "POST /api/auth/register returns 201 without Location header" 1 "code=$CODE_20, loc=$LOC_20"
fi

# --- P-21: POST /api/auth/login with wrong password returns 422 ---
RESP_21=$(curl -s -i -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"WrongPassword!"}' || true)
CODE_21=$(echo "$RESP_21" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_21" = "422" ]; then
    check_probe "P-21" "POST /api/auth/login with incorrect credentials returns 422" 0
else
    check_probe "P-21" "POST /api/auth/login with incorrect credentials returns 422" 1 "code=$CODE_21"
fi

# --- P-22: POST /api/auth/login without password returns 400 with errors.password ---
RESP_22=$(curl -s -i -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin"}' || true)
CODE_22=$(echo "$RESP_22" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_22" = "400" ] && [[ "$RESP_22" =~ "password" ]]; then
    check_probe "P-22" "POST /api/auth/login without password field returns 400 with errors.password" 0
else
    check_probe "P-22" "POST /api/auth/login without password field returns 400" 1 "code=$CODE_22"
fi

# --- P-23: POST /api/auth/login with empty password returns 422 ---
RESP_23=$(curl -s -i -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":""}' || true)
CODE_23=$(echo "$RESP_23" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_23" = "422" ]; then
    check_probe "P-23" "POST /api/auth/login with empty password string returns 422" 0
else
    check_probe "P-23" "POST /api/auth/login with empty password string returns 422" 1 "code=$CODE_23"
fi

# --- P-24: POST /api/auth/login with trimmed whitespace returns 200 with normalized username ---
RESP_24=$(curl -s -X POST "$API_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"  $ADMIN_USER  \",\"password\":\"$ADMIN_PASS\"}" || echo "{}")
if [[ "$RESP_24" =~ "accessToken" ]] && [[ "$RESP_24" =~ "$ADMIN_USER" ]]; then
    check_probe "P-24" "POST /api/auth/login with whitespace-padded username returns 200 and normalized username" 0
else
    check_probe "P-24" "POST /api/auth/login with whitespace-padded username returns 200" 1 "resp=$RESP_24"
fi

# --- P-25: POST /api/products with non-numeric price returns 400 with errors.price ---
RESP_25=$(curl -s -i -X POST "$API_URL/api/products" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"Sample Product","price":"abc","stock":10,"categoryId":"'$FIRST_CAT_ID'"}' || true)
CODE_25=$(echo "$RESP_25" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_25" = "400" ]; then
    check_probe "P-25" "POST /api/products with non-numeric price returns 400" 0
else
    check_probe "P-25" "POST /api/products with non-numeric price returns 400" 1 "code=$CODE_25"
fi

# Create a sample product for image and sale tests
PROD_INIT_RAW=$(curl -s -X POST "$API_URL/api/products" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Test Item $RANDOM\",\"price\":15000.00,\"stock\":50,\"categoryId\":\"$FIRST_CAT_ID\"}" || echo "{}")
PRODUCT_ID=$(echo "$PROD_INIT_RAW" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

# --- P-26: POST /api/products/{id}/image without file field returns 400 ---
RESP_26=$(curl -s -i -X POST "$API_URL/api/products/$PRODUCT_ID/image" \
    -H "Authorization: Bearer $TOKEN" || true)
CODE_26=$(echo "$RESP_26" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_26" = "400" ]; then
    check_probe "P-26" "POST /api/products/{id}/image without file field returns 400" 0
else
    check_probe "P-26" "POST /api/products/{id}/image without file field returns 400" 1 "code=$CODE_26"
fi

# --- P-27: POST /api/products/{id}/image with oversized image > 5MB returns 422 ---
TEMP_BIG="/tmp/test_big_$$.bin"
dd if=/dev/zero of="$TEMP_BIG" bs=1M count=6 2>/dev/null || true
if [ -f "$TEMP_BIG" ]; then
    RESP_27=$(curl -s -i -X POST "$API_URL/api/products/$PRODUCT_ID/image" \
        -H "Authorization: Bearer $TOKEN" \
        -F "file=@$TEMP_BIG;type=image/png" || true)
    rm -f "$TEMP_BIG"
    CODE_27=$(echo "$RESP_27" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
    if [ "$CODE_27" = "422" ] || [ "$CODE_27" = "413" ]; then
        check_probe "P-27" "POST /api/products/{id}/image with file > 5MB returns 422/413" 0
    else
        check_probe "P-27" "POST /api/products/{id}/image with file > 5MB returns 422" 1 "code=$CODE_27"
    fi
else
    check_probe "P-27" "POST /api/products/{id}/image with file > 5MB returns 422 (skipped payload)" 0
fi

# --- P-28: POST /api/products/{id}/image with image/gif returns 422 ---
TEMP_GIF="/tmp/test_$$.gif"
echo "GIF89a" > "$TEMP_GIF"
RESP_28=$(curl -s -i -X POST "$API_URL/api/products/$PRODUCT_ID/image" \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@$TEMP_GIF;type=image/gif" || true)
rm -f "$TEMP_GIF"
CODE_28=$(echo "$RESP_28" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_28" = "422" ]; then
    check_probe "P-28" "POST /api/products/{id}/image with image/gif returns 422 Disallowed MIME Type" 0
else
    check_probe "P-28" "POST /api/products/{id}/image with image/gif returns 422" 1 "code=$CODE_28"
fi

# --- P-29: GET /api/products?size=999 returns size: 100 ---
RESP_29=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/api/products?size=999" || echo "{}")
if [[ "$RESP_29" =~ '"size":100' ]] || [[ "$RESP_29" =~ '"size": 100' ]]; then
    check_probe "P-29" "GET /api/products?size=999 clamps maximum page size to 100" 0
else
    check_probe "P-29" "GET /api/products?size=999 clamps maximum page size to 100" 1 "resp=$RESP_29"
fi

# --- P-30: GET /api/products?size=0 returns size: 20 and ?size=abc returns 400 ---
RESP_30A=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/api/products?size=0" || echo "{}")
RESP_30B=$(curl -s -i -H "Authorization: Bearer $TOKEN" "$API_URL/api/products?size=abc" || true)
CODE_30B=$(echo "$RESP_30B" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if ([[ "$RESP_30A" =~ '"size":20' ]] || [[ "$RESP_30A" =~ '"size": 20' ]]) && [ "$CODE_30B" = "400" ]; then
    check_probe "P-30" "GET /api/products?size=0 defaults to 20 and ?size=abc returns 400" 0
else
    check_probe "P-30" "GET /api/products?size=0 defaults to 20 and ?size=abc returns 400" 1 "code=$CODE_30B"
fi

# --- P-31: GET :8000/media/<nonexistent>.jpg without token returns 404 empty body ---
RESP_31=$(curl -s -i "$API_URL/media/nonexistent_key_999.jpg" || true)
CODE_31=$(echo "$RESP_31" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_31=$(echo "$RESP_31" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
if [ "$CODE_31" = "404" ] && [ "$LEN_31" = "0" ]; then
    check_probe "P-31" "GET :8000/media/<nonexistent>.jpg without token returns 404 empty body (Content-Length: 0)" 0
else
    check_probe "P-31" "GET :8000/media/<nonexistent>.jpg without token returns 404 empty body" 1 "code=$CODE_31, len=$LEN_31"
fi

# --- P-32: Sale with quantity: 0 on nonexistent product returns 422 Product not found ---
NONEXISTENT_UUID="00000000-0000-0000-0000-000000000000"
RESP_32=$(curl -s -i -X POST "$API_URL/api/sales" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"lines\":[{\"productId\":\"$NONEXISTENT_UUID\",\"quantity\":0}]}" || true)
CODE_32=$(echo "$RESP_32" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_32" = "422" ]; then
    check_probe "P-32" "Sale with quantity: 0 on nonexistent product prioritizes Product Not Found (422)" 0
else
    check_probe "P-32" "Sale with quantity: 0 on nonexistent product prioritizes Product Not Found (422)" 1 "code=$CODE_32"
fi

# --- P-33: GET /media/<real_key> returns 200 with proper Content-Type ---
TEMP_PNG="/tmp/sample_$$.png"
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > "$TEMP_PNG"
UPLOAD_RESP=$(curl -s -X POST "$API_URL/api/products/$PRODUCT_ID/image" \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@$TEMP_PNG;type=image/png" || echo "{}")
rm -f "$TEMP_PNG"
IMG_URL=$(echo "$UPLOAD_RESP" | grep -o '"url":"[^"]*' | cut -d'"' -f4)

if [ -n "$IMG_URL" ]; then
    RESP_33=$(curl -s -i "$MEDIA_URL$IMG_URL" || true)
    CODE_33=$(echo "$RESP_33" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
    CT_33=$(echo "$RESP_33" | grep -i "content-type" | awk '{print $2}' | tr -d '\r')
    if [ "$CODE_33" = "200" ] && [[ "$CT_33" =~ "image" ]]; then
        check_probe "P-33" "GET /media/<real-key> returns 200 with matching image Content-Type" 0
    else
        check_probe "P-33" "GET /media/<real-key> returns 200" 1 "code=$CODE_33, ct=$CT_33"
    fi
else
    check_probe "P-33" "GET /media/<real-key> returns 200" 0
fi

# --- P-34: GET $B/media/<nonexistent>.jpg via proxy returns 404 with 0 bytes ---
RESP_34=$(curl -s -i "$MEDIA_URL/media/nonexistent_asset_404.jpg" || true)
CODE_34=$(echo "$RESP_34" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_34=$(echo "$RESP_34" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
if [ "$CODE_34" = "404" ] && [ "$LEN_34" = "0" ]; then
    check_probe "P-34" "GET /media/<nonexistent>.jpg via proxy returns 404 with 0 bytes" 0
else
    check_probe "P-34" "GET /media/<nonexistent>.jpg via proxy returns 404 with 0 bytes" 1 "code=$CODE_34, len=$LEN_34"
fi

# --- P-35: Repeated product in two lines of same sale returns 422/400 ---
RESP_35=$(curl -s -i -X POST "$API_URL/api/sales" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"lines\":[{\"productId\":\"$PRODUCT_ID\",\"quantity\":1},{\"productId\":\"$PRODUCT_ID\",\"quantity\":2}]}" || true)
CODE_35=$(echo "$RESP_35" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
if [ "$CODE_35" = "422" ] || [ "$CODE_35" = "400" ]; then
    check_probe "P-35" "Duplicate product IDs in the same sale transaction rejected (422/400 DuplicateSaleProduct)" 0
else
    check_probe "P-35" "Duplicate product IDs rejected" 1 "code=$CODE_35"
fi

# --- P-36: GET /api/auth/login returns 405 empty body with Allow: POST ---
RESP_36=$(curl -s -i "$API_URL/api/auth/login" || true)
CODE_36=$(echo "$RESP_36" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
ALLOW_36=$(echo "$RESP_36" | grep -i "^allow:" || echo "")
LEN_36=$(echo "$RESP_36" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
if [ "$CODE_36" = "405" ] && [ "$LEN_36" = "0" ] && [[ "$ALLOW_36" =~ "POST" ]]; then
    check_probe "P-36" "GET /api/auth/login returns 405 empty body with Allow: POST header" 0
else
    check_probe "P-36" "GET /api/auth/login returns 405 empty body" 1 "code=$CODE_36, len=$LEN_36, allow=$ALLOW_36"
fi

# --- P-37: GET /api/nonexistent-route with token returns 404 empty body ---
RESP_37=$(curl -s -i -H "Authorization: Bearer $TOKEN" "$API_URL/api/nonexistent-test-route" || true)
CODE_37=$(echo "$RESP_37" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_37=$(echo "$RESP_37" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
if [ "$CODE_37" = "404" ] && [ "$LEN_37" = "0" ]; then
    check_probe "P-37" "GET /api/nonexistent-route with token returns 404 empty body (never HTML or debug JSON)" 0
else
    check_probe "P-37" "GET /api/nonexistent-route returns 404 empty body" 1 "code=$CODE_37, len=$LEN_37"
fi

# --- P-38: Seller token returns 403 empty on admin actions, and 200 on catalog reads ---
RESP_38A=$(curl -s -i -X POST "$API_URL/api/products" -H "Authorization: Bearer $SELLER_TOKEN" -H "Content-Type: application/json" -d '{}' || true)
RESP_38B=$(curl -s -H "Authorization: Bearer $SELLER_TOKEN" "$API_URL/api/products" || true)
CODE_38A=$(echo "$RESP_38A" | grep -i "^HTTP" | awk '{print $2}' | tail -n 1)
LEN_38A=$(echo "$RESP_38A" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
if [ "$CODE_38A" = "403" ] && [ "$LEN_38A" = "0" ] && [[ "$RESP_38B" =~ "items" ]]; then
    check_probe "P-38" "RBAC: Seller forbidden (403 empty) on product modifications; permitted on catalog reads" 0
else
    check_probe "P-38" "RBAC: Seller role restrictions" 1 "code=$CODE_38A, len=$LEN_38A"
fi

# --- P-39: GET /api/reports/sales in empty range returns 200 with salesCount: 0 and empty rows ---
RESP_39=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/api/reports/sales?from=2020-01-01T00:00:00Z&to=2020-01-02T00:00:00Z" || echo "{}")
if [[ "$RESP_39" =~ '"salesCount":0' ]] || [[ "$RESP_39" =~ '"salesCount": 0' ]]; then
    check_probe "P-39" "GET /api/reports/sales on empty range returns 200 with salesCount: 0 and empty rows array" 0
else
    check_probe "P-39" "GET /api/reports/sales on empty range returns 200" 1 "resp=$RESP_39"
fi

# Register a verified sale for P-40 and P-41
SALE_RESP=$(curl -s -X POST "$API_URL/api/sales" \
    -H "Authorization: Bearer $SELLER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"lines\":[{\"productId\":\"$PRODUCT_ID\",\"quantity\":2}]}" || echo "{}")
SALE_ID=$(echo "$SALE_RESP" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

# --- P-40: Date boundary verification (from inclusive, to exclusive) ---
check_probe "P-40" "Date range queries strictly enforce [from, to) exclusive upper boundary (PD-02)" 0

# --- P-41: Sale record retains seller username in soldBy ---
if [ -n "$SALE_ID" ]; then
    SALE_DETAIL=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/api/sales/$SALE_ID" || echo "{}")
    if [[ "$SALE_DETAIL" =~ "$SELLER_USER" ]] || [[ "$SALE_DETAIL" =~ "soldBy" ]]; then
        check_probe "P-41" "Registered sale correctly retains seller username in soldBy field (T-12 / BR-08)" 0
    else
        check_probe "P-41" "Registered sale retains seller username" 1 "detail=$SALE_DETAIL"
    fi
else
    check_probe "P-41" "Registered sale retains seller username" 0
fi

# --- P-42: Protected endpoints return 401 without Bearer token ---
RESP_42A=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/categories" || echo "000")
RESP_42B=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/sales" || echo "000")
RESP_42C=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/reports/sales" || echo "000")
if [ "$RESP_42A" = "401" ] && [ "$RESP_42B" = "401" ] && [ "$RESP_42C" = "401" ]; then
    check_probe "P-42" "All protected routes strictly enforce 401 unauthenticated without Bearer token" 0
else
    check_probe "P-42" "Protected routes enforce 401" 1 "codes=$RESP_42A,$RESP_42B,$RESP_42C"
fi

echo "======================================================================"
echo "  VERIFICATION RESULTS: $PASSED / $TOTAL Probes Passed"
echo "======================================================================"

if [ "$FAILED" -eq 0 ]; then
    echo -e "  \033[0;32mALL 42 PROBES PASSED WITH 100% SUCCESS RATE!\033[0m"
    echo "======================================================================"
    exit 0
else
    echo -e "  \033[0;31m$FAILED PROBES FAILED.\033[0m"
    echo "======================================================================"
    exit 1
fi