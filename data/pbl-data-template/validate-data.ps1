[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$SettingsFile,
  [string]$MappingFile,
  [string]$DataFile
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'data-contract.ps1')
$settingsPath=(Resolve-Path -LiteralPath $SettingsFile).Path
. $settingsPath
if (-not $DataFile) { $DataFile=Join-Path (Split-Path $settingsPath) "generated\$IndexName-$DocumentCount.ndjson" }
$DataFile=(Resolve-Path -LiteralPath $DataFile).Path
if ($MappingFile) { $MappingFile=(Resolve-Path -LiteralPath $MappingFile).Path }
$summaryPath=Join-Path (Split-Path $DataFile) 'generation-summary.json'
$summary=Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($summary.index -cne $IndexName -or $summary.document_count -ne $DocumentCount) { throw 'Summary differs from settings; regenerate.' }
if ($summary.settings_sha256 -and $summary.settings_sha256 -ne (Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash) { throw 'Settings changed since generation; regenerate.' }
if ($summary.bulk_sha256 -and $summary.bulk_sha256 -ne (Get-FileHash -LiteralPath $DataFile -Algorithm SHA256).Hash) { throw 'Bulk file changed since generation; regenerate.' }
if ($MappingFile -and $summary.mapping_sha256 -and $summary.mapping_sha256 -ne (Get-FileHash -LiteralPath $MappingFile -Algorithm SHA256).Hash) { throw 'Mapping changed since generation; recheck and regenerate.' }
$count=Test-BulkFile $DataFile $IndexName $DocumentCount $MappingFile $IdField
Write-Host "LOCAL CHECK PASS: $count documents, unique IDs, target index and NDJSON verified. This is not an Elasticsearch indexing result."
