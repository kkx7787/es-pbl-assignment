[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SettingsFile,
  [Parameter(Mandatory = $true)]
  [string]$DockerDirectory,
  [string]$DataFile,
  [string]$MappingFile
)

$ErrorActionPreference = 'Stop'
$settingsPath = Resolve-Path -LiteralPath $SettingsFile -ErrorAction Stop
. $settingsPath
if ($IndexName -notmatch '^[a-z0-9][a-z0-9_-]*$') { throw 'IndexName은 소문자, 숫자, 하이픈, 밑줄만 사용합니다.' }
if (-not $DataFile) { $DataFile = Join-Path (Join-Path (Split-Path -Parent $settingsPath) 'generated') ("{0}-{1}.ndjson" -f $IndexName, $DocumentCount) }
if (-not (Test-Path -LiteralPath $DataFile)) { throw "Bulk 데이터 파일이 없습니다: $DataFile" }
$DataFile = (Resolve-Path -LiteralPath $DataFile).Path
& (Join-Path $PSScriptRoot 'validate-data.ps1') -SettingsFile $settingsPath.Path -DataFile $DataFile -MappingFile $MappingFile
if (-not $?) { throw 'Local data validation failed.' }
$dockerRoot = Resolve-Path -LiteralPath $DockerDirectory -ErrorAction Stop

Push-Location $dockerRoot
try {
  if (-not (Test-Path -LiteralPath '.env')) { throw '.env가 없습니다. Day 1 Docker 환경을 먼저 준비합니다.' }
  $containerId = (docker compose ps -q es01).Trim()
  if (-not $containerId) { throw 'es01 컨테이너가 실행 중이지 않습니다. Day 1의 start.ps1 후 다시 실행합니다.' }
  $passwordLine = Get-Content .env | Where-Object { $_ -match '^ELASTIC_PASSWORD=' } | Select-Object -First 1
  if (-not $passwordLine) { throw '.env에서 ELASTIC_PASSWORD를 찾지 못했습니다.' }
  $password = $passwordLine.Split('=', 2)[1]
  $existing = docker compose exec -T es01 sh -c "curl -fsS --cacert config/certs/ca/ca.crt -u 'elastic:$password' 'https://localhost:9200/$IndexName/_mapping'"
  if ($LASTEXITCODE -ne 0) { throw 'Target index/mapping is not available. Check T12; no automatic creation.' }
  $containerFile = '/tmp/pbl-bulk.ndjson'
  docker cp $DataFile "${containerId}:$containerFile"
  if ($LASTEXITCODE -ne 0) { throw 'Bulk 데이터 파일을 es01 컨테이너로 복사하지 못했습니다.' }
  $bulk = docker compose exec -T es01 sh -c "curl -s --cacert config/certs/ca/ca.crt -u 'elastic:$password' -H 'Content-Type: application/x-ndjson' -X POST 'https://localhost:9200/_bulk?refresh=wait_for&filter_path=errors,items.*.error' --data-binary @$containerFile"
  if ($LASTEXITCODE -ne 0) { throw "Bulk request failed: $bulk" }
  $bulkResult = ($bulk -join "`n") | ConvertFrom-Json
  if ($null -eq $bulkResult.errors -or $bulkResult.errors -ne $false) { throw "Bulk 적재 실패: $bulk" }
  $count = docker compose exec -T es01 sh -c "curl -s --cacert config/certs/ca/ca.crt -u 'elastic:$password' 'https://localhost:9200/$IndexName/_count'"
  if ($LASTEXITCODE -ne 0) { throw "Count request failed: $count" }
  $countResult = ($count -join "`n") | ConvertFrom-Json
  if ($null -eq $countResult.count -or $countResult._shards.failed -gt 0) { throw "Count validation failed: $count" }
  Write-Host "PASS: Bulk item errors=false. Actual count=$($countResult.count), generated=$DocumentCount. Validate distribution separately."
  if ($countResult.count -ne $DocumentCount) { Write-Warning 'Actual count differs from generated count. Check existing documents and IDs; do not delete automatically.' }
} finally {
  Pop-Location
}
