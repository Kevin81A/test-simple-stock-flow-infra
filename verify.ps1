# ==============================================================================
# Simple Stock Flow · Script de Verificación Integral (PowerShell)
# Prueba técnica SDD · SENA ADSO Ficha 3413974
# ==============================================================================

$ApiUrl = if ($env:API_URL) { $env:API_URL } else { "http://localhost:8000" }
$AppUrl = if ($env:APP_URL) { $env:APP_URL } else { "http://localhost:8080" }
$AdminUser = if ($env:ADMIN_USER) { $env:ADMIN_USER } else { "admin" }
$AdminPass = if ($env:ADMIN_PASS) { $env:ADMIN_PASS } else { "Admin12345!" }

$failed = 0

function Check-Probe($name, $condition) {
    if ($condition) {
        Write-Host "  [PASÓ] $name" -ForegroundColor Green
    } else {
        Write-Host "  [FALLÓ] $name" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "======================================================================"
Write-Host "  Iniciando sondas de verificación para Simple Stock Flow"
Write-Host "======================================================================"

# P-01: Healthcheck
try {
    $res = Invoke-WebRequest -Uri "$ApiUrl/health" -Method Get -UseBasicParsing -TimeoutSec 5
    Check-Probe "P-01: Healthcheck 200 OK" ($res.StatusCode -eq 200 -and $res.Content -like "*ok*")
} catch {
    Check-Probe "P-01: Healthcheck 200 OK" $false
}

# P-02: 401 Empty Body
try {
    $res = Invoke-WebRequest -Uri "$ApiUrl/api/products" -Method Get -UseBasicParsing -TimeoutSec 5
    Check-Probe "P-02: 401 sin autenticación tiene cuerpo vacío" $false
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    $len = $_.Exception.Response.Headers["Content-Length"]
    Check-Probe "P-02: 401 sin autenticación tiene cuerpo vacío" ($status -eq 401 -and ($len -eq "0" -or [string]::IsNullOrEmpty($len)))
}

# P-03: 404 Empty Body
try {
    $res = Invoke-WebRequest -Uri "$ApiUrl/api/ruta-inexistente" -Method Get -UseBasicParsing -TimeoutSec 5
    Check-Probe "P-03: 404 ruta inexistente tiene cuerpo vacío" $false
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    $len = $_.Exception.Response.Headers["Content-Length"]
    Check-Probe "P-03: 404 ruta inexistente tiene cuerpo vacío" ($status -eq 404 -and ($len -eq "0" -or [string]::IsNullOrEmpty($len)))
}

# P-04: Admin login
$token = $null
try {
    $body = @{ username = $AdminUser; password = $AdminPass } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$ApiUrl/api/auth/login" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 5
    $token = $res.accessToken
    Check-Probe "P-04: Autenticación exitosa y JWT obtenido" ($token -ne $null)
} catch {
    Check-Probe "P-04: Autenticación exitosa y JWT obtenido" $false
}

# P-05: Categories count = 5
if ($token) {
    try {
        $headers = @{ Authorization = "Bearer $token" }
        $cats = Invoke-RestMethod -Uri "$ApiUrl/api/categories" -Method Get -Headers $headers -TimeoutSec 5
        Check-Probe "P-05: 5 categorías semilla presentes" ($cats.Count -eq 5)
    } catch {
        Check-Probe "P-05: 5 categorías semilla presentes" $false
    }
}

# P-06: 400 Bad Request RFC 7807
if ($token) {
    try {
        $badBody = @{ name = ""; price = -10 } | ConvertTo-Json
        $headers = @{ Authorization = "Bearer $token" }
        Invoke-WebRequest -Uri "$ApiUrl/api/products" -Method Post -Headers $headers -Body $badBody -ContentType "application/json" -TimeoutSec 5
        Check-Probe "P-06: 400 Bad Request retorna problem+json" $false
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        $cType = $_.Exception.Response.Headers["Content-Type"]
        Check-Probe "P-06: 400 Bad Request retorna problem+json" ($status -eq 400 -and $cType -like "*problem+json*")
    }
}

# P-07: Frontend App
try {
    $res = Invoke-WebRequest -Uri "$AppUrl/" -Method Get -UseBasicParsing -TimeoutSec 5
    Check-Probe "P-07: Frontend disponible con lang=es" ($res.StatusCode -eq 200 -and ($res.Content -like '*lang="es"*' -or $res.Content -like "*Simple Stock Flow*"))
} catch {
    Check-Probe "P-07: Frontend disponible con lang=es" $false
}

Write-Host "======================================================================"
if ($failed -eq 0) {
    Write-Host "  ¡TODAS LAS SONDAS DE VERIFICACIÓN PASARON EXITOSAMENTE!" -ForegroundColor Green
} else {
    Write-Host "  SE ENCONTRARON $failed FALLOS EN LA VERIFICACIÓN." -ForegroundColor Red
}
Write-Host "======================================================================"
