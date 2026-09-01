[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SettingsFile,
  [string]$OutputDirectory,
  [string]$MappingFile,
  [string]$FixedDocumentsFile
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\data-contract.ps1')

function Get-RequiredValue([System.Collections.IDictionary]$Rule, [string]$Name) {
  if (-not $Rule.Contains($Name) -or $null -eq $Rule[$Name] -or ($Rule[$Name] -is [string] -and [string]::IsNullOrWhiteSpace($Rule[$Name]))) {
    throw "field '$($Rule.Name)'의 $Name 설정이 필요합니다."
  }
  return $Rule[$Name]
}

function Get-Choice([object[]]$Values, [System.Random]$Random) {
  if ($null -eq $Values -or $Values.Count -eq 0) { throw '선택 후보가 비어 있습니다.' }
  return $Values[$Random.Next($Values.Count)]
}

function Get-WeightedChoice([object[]]$Values, [System.Random]$Random) {
  $total = 0.0
  foreach ($item in $Values) { $total += [double]$item.Weight }
  if ($total -le 0) { throw 'weighted_choice의 Weight 합계는 0보다 커야 합니다.' }
  $point = $Random.NextDouble() * $total
  $running = 0.0
  foreach ($item in $Values) {
    $running += [double]$item.Weight
    if ($point -lt $running) { return $item.Value }
  }
  return $Values[$Values.Count - 1].Value
}

function Get-TemplateValue([string]$Template, [System.Collections.IDictionary]$Document, [int]$Sequence) {
  $value = $Template.Replace('{{sequence}}', $Sequence.ToString())
  foreach ($key in $Document.Keys) {
    $replacement = if ($Document[$key] -is [array]) { [string]::Join(' ', $Document[$key]) } else { [string]$Document[$key] }
    $value = $value.Replace(('{{' + $key + '}}'), $replacement)
  }
  if ($value -match '\{\{.+?\}\}') { throw "template에 아직 채워지지 않은 값이 있습니다: $Template" }
  return $value
}

function Get-RuleValue([System.Collections.IDictionary]$Rule, [System.Collections.IDictionary]$Document, [int]$Sequence, [System.Random]$Random, [System.Collections.IDictionary]$Vocabulary) {
  $kind = Get-RequiredValue $Rule 'Kind'
  switch ($kind) {
    'id' {
      $digits = if ($Rule.Contains('Digits')) { [int]$Rule.Digits } else { 5 }
      return ('{0}-{1}' -f $IdPrefix, $Sequence.ToString("D$digits"))
    }
    'choice' {
      $source = Get-RequiredValue $Rule 'Source'
      if (-not $Vocabulary.Contains($source)) { throw "field '$($Rule.Name)'의 Source '$source'가 Vocabularies에 없습니다." }
      return Get-Choice @($Vocabulary[$source]) $Random
    }
    'weighted_choice' { return Get-WeightedChoice @(Get-RequiredValue $Rule 'Values') $Random }
    'integer' { return $Random.Next([int](Get-RequiredValue $Rule 'Min'), ([int](Get-RequiredValue $Rule 'Max')) + 1) }
    'decimal' {
      $number = [double](Get-RequiredValue $Rule 'Min') + ($Random.NextDouble() * ([double](Get-RequiredValue $Rule 'Max') - [double](Get-RequiredValue $Rule 'Min')))
      $digits = if ($Rule.Contains('Digits')) { [int]$Rule.Digits } else { 2 }
      return [math]::Round($number, $digits)
    }
    'date' {
      $start = [datetime]::Parse((Get-RequiredValue $Rule 'Start')).ToUniversalTime()
      $end = [datetime]::Parse((Get-RequiredValue $Rule 'End')).ToUniversalTime()
      if ($end -lt $start) { throw "field '$($Rule.Name)'의 End는 Start보다 빠를 수 없습니다." }
      return $start.AddSeconds([math]::Floor($Random.NextDouble() * ($end - $start).TotalSeconds)).ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
    'boolean' { return ($Random.NextDouble() -lt [double](Get-RequiredValue $Rule 'TrueRatio')) }
    'tags' {
      $source = Get-RequiredValue $Rule 'Source'
      if (-not $Vocabulary.Contains($source)) { throw "field '$($Rule.Name)'의 Source '$source'가 Vocabularies에 없습니다." }
      $values = @($Vocabulary[$source] | Sort-Object { $Random.Next() })
      $min = [int](Get-RequiredValue $Rule 'MinItems')
      $max = [int](Get-RequiredValue $Rule 'MaxItems')
      if ($min -lt 1 -or $max -lt $min -or $max -gt $values.Count) { throw "field '$($Rule.Name)'의 MinItems/MaxItems 범위가 후보 수와 맞지 않습니다." }
      $selected = @($values | Select-Object -First ($Random.Next($min, $max + 1)))
      return ,$selected
    }
    'template' { return Get-TemplateValue (Get-RequiredValue $Rule 'Template') $Document $Sequence }
    default { throw "지원하지 않는 Kind입니다: $kind" }
  }
}

$resolvedSettings = Resolve-Path -LiteralPath $SettingsFile -ErrorAction Stop
if (-not $OutputDirectory) {
  $OutputDirectory = Join-Path (Split-Path -Parent $resolvedSettings.Path) 'generated'
}
. $resolvedSettings
foreach ($required in @('IndexName', 'DocumentCount', 'Seed', 'IdPrefix', 'IdField', 'SampleCount', 'Vocabularies', 'FieldRules')) {
  if ($null -eq (Get-Variable -Name $required -ErrorAction SilentlyContinue).Value) { throw "설정 파일에 `$$required 변수가 없습니다." }
}
if ($IndexName -notmatch '^[a-z0-9][a-z0-9_-]*$') { throw 'IndexName은 소문자, 숫자, 하이픈, 밑줄만 사용합니다.' }
if ($DocumentCount -lt $SampleCount -or $SampleCount -lt 1) { throw 'DocumentCount는 SampleCount 이상이고 SampleCount는 1 이상이어야 합니다.' }
if (-not (@($FieldRules.Name) -contains $IdField)) { throw "IdField '$IdField'에 해당하는 field 규칙이 없습니다." }

# Validate configuration before touching any previously generated files.
if ($DocumentCount -gt 100000 -or $DocumentCount -ne [int]$DocumentCount) { throw 'DocumentCount must be an integer up to 100000 for this classroom template.' }
if ($SampleCount -ne [int]$SampleCount) { throw 'SampleCount must be an integer.' }
$known = @{}
foreach ($rule in $FieldRules) {
  if ($rule.Name -notmatch '^[A-Za-z][A-Za-z0-9_]*$' -or $known.ContainsKey($rule.Name)) { throw "Invalid or duplicate field Name: $($rule.Name)" }
  foreach ($ratio in @('MissingRatio','TrueRatio')) {
    if ($rule.Contains($ratio) -and ([double]$rule[$ratio] -lt 0 -or [double]$rule[$ratio] -gt 1 -or [double]::IsNaN([double]$rule[$ratio]))) { throw "$ratio must be between 0 and 1: $($rule.Name)" }
  }
  if ($rule.Kind -in @('integer','decimal')) {
    foreach ($bound in @('Min','Max')) { if ([double]::IsNaN([double]$rule[$bound]) -or [double]::IsInfinity([double]$rule[$bound])) { throw "Numeric bounds must be finite: $($rule.Name)" } }
    if ([double]$rule.Min -gt [double]$rule.Max) { throw "Min exceeds Max: $($rule.Name)" }
    if ($rule.Kind -eq 'integer' -and ([double]$rule.Min -lt [int]::MinValue -or [double]$rule.Max -ge [int]::MaxValue -or [double]$rule.Min -ne [int]$rule.Min -or [double]$rule.Max -ne [int]$rule.Max)) { throw "integer bounds must be valid Int32 values below Int32.MaxValue: $($rule.Name)" }
  }
  if ($rule.Kind -eq 'weighted_choice') {
    foreach ($item in @($rule.Values)) { if ($null -eq $item.Value -or $null -eq $item.Weight -or [double]$item.Weight -lt 0 -or [double]::IsNaN([double]$item.Weight) -or [double]::IsInfinity([double]$item.Weight)) { throw "Invalid weighted choice: $($rule.Name)" } }
  }
  if ($rule.Kind -eq 'template') {
    foreach ($match in [regex]::Matches($rule.Template,'\{\{(.+?)\}\}')) {
      $ref = $match.Groups[1].Value
      if ($ref -ne 'sequence' -and (-not $known.ContainsKey($ref) -or [double]$known[$ref].MissingRatio -gt 0)) { throw "Template must reference an earlier, non-missing field: $ref" }
    }
  }
  $known[$rule.Name] = $rule
}
if ($known[$IdField].Kind -ne 'id' -or [double]$known[$IdField].MissingRatio -gt 0) { throw 'IdField must use Kind=id without missing values.' }
$properties = $null
if ($MappingFile) {
  $MappingFile = (Resolve-Path -LiteralPath $MappingFile -ErrorAction Stop).Path
  $mapping = Get-Content -LiteralPath $MappingFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $properties = $mapping.mappings.properties
  if (-not $properties) { throw 'MappingFile must contain a complete creation body with mappings.properties.' }
  foreach ($name in $known.Keys) { if (-not $properties.PSObject.Properties[$name]) { throw "FieldRule absent from mapping: $name" } }
}
$fixedDocs = @()
if ($FixedDocumentsFile) {
  if (-not $MappingFile) { throw 'FixedDocumentsFile requires MappingFile.' }
  $FixedDocumentsFile = (Resolve-Path -LiteralPath $FixedDocumentsFile).Path
  $fixedText = Get-Content -LiteralPath $FixedDocumentsFile -Raw -Encoding UTF8
  if (-not $fixedText.TrimStart().StartsWith('[')) { throw 'FixedDocumentsFile must be a JSON array.' }
  $fixedDocs = ConvertFrom-Json -InputObject $fixedText
  if ($fixedDocs.Count -gt $DocumentCount) { throw 'Too many fixed documents.' }
  foreach ($fixed in $fixedDocs) { Assert-DocumentMapping $fixed $properties }
}

$null = New-Item -ItemType Directory -Force -Path $OutputDirectory
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$bulkPath = Join-Path $OutputDirectory ("{0}-{1}.ndjson" -f $IndexName, $DocumentCount)
$samplePath = Join-Path $OutputDirectory ("{0}-sample-{1}.ndjson" -f $IndexName, $SampleCount)
$summaryPath = Join-Path $OutputDirectory 'generation-summary.json'
$random = [System.Random]::new([int]$Seed)
$bulkLines = [Collections.Generic.List[string]]::new()
$sampleLines = [Collections.Generic.List[string]]::new()

& {
  for ($sequence = 1; $sequence -le $DocumentCount; $sequence++) {
    $document = [ordered]@{}
    foreach ($rule in $FieldRules) {
      if ($rule.Contains('MissingRatio') -and $random.NextDouble() -lt [double]$rule.MissingRatio) { continue }
      $document[$rule.Name] = Get-RuleValue $rule $document $sequence $random $Vocabularies
    }
    if (-not $document.Contains($IdField)) { throw "문서 $sequence 에 IdField '$IdField'가 없습니다." }
    if ($sequence -le $fixedDocs.Count) {
      $generatedId = $document[$IdField]
      $document = [ordered]@{}
      foreach ($property in $fixedDocs[$sequence-1].PSObject.Properties) { $document[$property.Name] = $property.Value }
      $document[$IdField] = $generatedId
    }
    if ($properties) { Assert-DocumentMapping ([pscustomobject]$document) $properties }
    $action = [ordered]@{ index = [ordered]@{ _index = $IndexName; _id = $document[$IdField] } }
    $actionJson = $action | ConvertTo-Json -Compress
    $documentJson = $document | ConvertTo-Json -Compress -Depth 6
    $bulkLines.Add($actionJson); $bulkLines.Add($documentJson)
    if ($sequence -le $SampleCount) { $sampleLines.Add($actionJson); $sampleLines.Add($documentJson) }
  }
}
[IO.File]::WriteAllLines($bulkPath,$bulkLines,$utf8NoBom)
[IO.File]::WriteAllLines($samplePath,$sampleLines,$utf8NoBom)

$summary = [ordered]@{
  index = $IndexName; document_count = $DocumentCount; seed = $Seed; id_field = $IdField
  files = [ordered]@{ bulk = (Split-Path -Leaf $bulkPath); sample = (Split-Path -Leaf $samplePath) }
  field_kinds = @($FieldRules | ForEach-Object { [ordered]@{ name = $_.Name; kind = $_.Kind } })
  generated_at = 'deterministic-from-seed'
  fixed_document_count = $fixedDocs.Count
  settings_sha256 = (Get-FileHash -LiteralPath $resolvedSettings.Path -Algorithm SHA256).Hash
  bulk_sha256 = (Get-FileHash -LiteralPath $bulkPath -Algorithm SHA256).Hash
  mapping_sha256 = $(if ($MappingFile) { (Get-FileHash -LiteralPath $MappingFile -Algorithm SHA256).Hash } else { $null })
}
[System.IO.File]::WriteAllText($summaryPath, (($summary | ConvertTo-Json -Depth 6) + [Environment]::NewLine), $utf8NoBom)
Write-Host "생성 완료: $DocumentCount 건"
Write-Host "Bulk 파일: $bulkPath"
Write-Host "표본 파일: $samplePath"
