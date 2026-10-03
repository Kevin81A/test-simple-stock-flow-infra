# ==============================================================================
# Simple Stock Flow · Full Verification Suite (PowerShell)
# SDD Technical Test · SENA ADSO Class 3413974
# ==============================================================================

$ApiUrl = if ($env:API_URL) { $env:API_URL } else { "http://localhost:8000" }
$AppUrl = if ($env:APP_URL) { $env:APP_URL } else { "http://localhost:8080" }
$AdminUser = if ($env:ADMIN_USER) { $env:ADMIN_USER } else { "admin" }
$AdminPass = if ($env:ADMIN_PASS) { $env:ADMIN_PASS } else { "Admin12345!" }

$failed = 0

function Check-Probe($name, $condition) {
    if ($condition) {
        Write-Host "  [PASSED] $name" -ForegroundColor Green
    } else {
        Write-Host "  [FAILED] $name" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "======================================================================"
Write-Host "  Starting verification probes for Simple Stock Flow"
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
    Check-Probe "P-02: 401 unauthenticated request has empty body" $false
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    $len = $_.Exception.Response.Headers["Content-Length"]
    Check-Probe "P-02: 401 unauthenticated request has empty body" ($status -eq 401 -and ($len -eq "0" -or [string]::IsNullOrEmpty($len)))
}

# P-03: 404 Empty Body
try {
    $res = Invoke-WebRequest -Uri "$ApiUrl/api/nonexistent-route" -Method Get -UseBasicParsing -TimeoutSec 5
    Check-Probe "P-03: 404 not found route has empty body" $false
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    $len = $_.Exception.Response.Headers["Content-Length"]
    Check-Probe "P-03: 404 not found route has empty body" ($status -eq 404 -and ($len -eq "0" -or [string]::IsNullOrEmpty($len)))
}

# P-04: Admin login
$token = $null
try {
    $body = @{ username = $AdminUser; password = $AdminPass } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$ApiUrl/api/auth/login" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 5
    $token = $res.accessToken
    Check-Probe "P-04: Admin login successful and JWT retrieved" ($token -ne $null)
} catch {
    Check-Probe "P-04: Admin login successful and JWT retrieved" $false
}

# P-05: Categories count = 5
if ($token) {
    try {
        $headers = @{ Authorization = "Bearer $token" }
        $cats = Invoke-RestMethod -Uri "$ApiUrl/api/categories" -Method Get -Headers $headers -TimeoutSec 5
        Check-Probe "P-05: 5 seed categories present" ($cats.Count -eq 5)
    } catch {
        Check-Probe "P-05: 5 seed categories present" $false
    }
}

# P-06: 400 Bad Request RFC 7807
if ($token) {
    try {
        $badBody = @{ name = ""; price = -10 } | ConvertTo-Json
        $headers = @{ Authorization = "Bearer $token" }
        Invoke-WebRequest -Uri "$ApiUrl/api/products" -Method Post -Headers $headers -Body $badBody -ContentType "application/json" -TimeoutSec 5
        Check-Probe "P-06: 400 Bad Request returns problem+json" $false
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        $cType = $_.Exception.Response.Headers["Content-Type"]
        Check-Probe "P-06: 400 Bad Request returns problem+json" ($status -eq 400 -and $cType -like "*problem+json*")
    }
}

# P-07: Frontend App
try {
    $res = Invoke-WebRequest -Uri "$AppUrl/" -Method Get -UseBasicParsing -TimeoutSec 5
    Check-Probe "P-07: Frontend App available and serving SPA" ($res.StatusCode -eq 200 -and $res.Content -like "*Simple Stock Flow*")
} catch {
    Check-Probe "P-07: Frontend App available and serving SPA" $false
}

Write-Host "======================================================================"
if ($failed -eq 0) {
    Write-Host "  ALL VERIFICATION PROBES PASSED SUCCESSFULLY!" -ForegroundColor Green
} else {
    Write-Host "  FOUND $failed VERIFICATION FAILURES." -ForegroundColor Red
}
Write-Host "======================================================================"