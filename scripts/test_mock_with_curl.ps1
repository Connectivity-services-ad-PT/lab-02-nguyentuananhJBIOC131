$ErrorActionPreference = "Stop"

$BaseUrl = if ($env:BASE_URL) { $env:BASE_URL } else { "http://localhost:4010" }
$AuthHeader = "Authorization: Bearer test-token"

Write-Host "[Lab02] Testing Prism mock server at $BaseUrl for Group A1 - IoT Ingestion"
Write-Host ""

Write-Host "[1/5] Happy path: GET /health (Kiem tra trang thai)"
curl.exe -i "$BaseUrl/health"
Write-Host "`n---"

Write-Host "[2/5] Happy path: GET /api/v1/telemetry (Lay lich su du lieu cam bien)"
curl.exe -i "$BaseUrl/api/v1/telemetry?limit=5" -H $AuthHeader
Write-Host "`n---"

Write-Host "[3/5] Happy path: POST /api/v1/telemetry (Gui du lieu cam bien hop le)"
$payload = '{
  "device_id": "SENSOR_A201_01",
  "timestamp": "2026-05-27T09:30:00Z",
  "readings": {
    "temperature": 26.5,
    "humidity": 65.2,
    "co2": 850
  }
}'
curl.exe -i -X POST "$BaseUrl/api/v1/telemetry" -H $AuthHeader -H "Content-Type: application/json" -d $payload
Write-Host "`n---"

Write-Host "[4/5] Error case: GET /api/v1/telemetry without token (Loi 401 - Chua xac thuc)"
curl.exe -i "$BaseUrl/api/v1/telemetry"
Write-Host "`n---"

Write-Host "[5/5] Error case: POST /api/v1/telemetry invalid payload (Loi 400 - Thieu device_id)"
$badPayload = '{
  "timestamp": "2026-05-27T09:30:00Z",
  "readings": {
    "temperature": 26.5
  }
}'
curl.exe -i -X POST "$BaseUrl/api/v1/telemetry" -H $AuthHeader -H "Content-Type: application/json" -d $badPayload
Write-Host ""