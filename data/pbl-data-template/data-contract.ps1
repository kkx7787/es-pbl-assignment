# Shared local checks. No network or Elasticsearch writes.
function Assert-DocumentMapping($Document, $Properties) {
  if ($null -eq $Document -or $Document -isnot [pscustomobject]) { throw 'Document must be a JSON object.' }
  foreach ($property in $Document.PSObject.Properties) {
    $definition = $Properties.PSObject.Properties[$property.Name]
    if (-not $definition) { throw "Undefined mapping field: $($property.Name)" }
    $type = $definition.Value.type
    $value = $property.Value
    if ($null -eq $value) { continue }
    foreach ($item in @($value)) {
      if ($null -eq $item) { continue }
      switch ($type) {
        { $_ -in @('text','keyword') } { if ($item -isnot [string]) { throw "Expected string: $($property.Name)" } }
        'boolean' { if ($item -isnot [bool]) { throw "Expected boolean: $($property.Name)" } }
        { $_ -in @('integer','long','short','byte') } {
          if ($item -is [string] -or $item -is [bool] -or $item -isnot [ValueType] -or [double]$item -ne [math]::Truncate([double]$item)) { throw "Expected integer: $($property.Name)" }
          $limits = @{ integer=@(-2147483648L,2147483647L); short=@(-32768,32767); byte=@(-128,127); long=@([long]::MinValue,[long]::MaxValue) }
          if ($item -lt $limits[$type][0] -or $item -gt $limits[$type][1]) { throw "Integer outside mapping range: $($property.Name)" }
        }
        { $_ -in @('float','double','half_float','scaled_float') } {
          if ($item -is [string] -or $item -is [bool] -or $item -isnot [ValueType] -or [double]::IsNaN([double]$item) -or [double]::IsInfinity([double]$item)) { throw "Expected finite number: $($property.Name)" }
        }
        'date' {
          $parsed = [datetimeoffset]::MinValue
          if ($item -isnot [string] -or $item -notmatch '^\d{4}-\d{2}-\d{2}(T.*(Z|[+-]\d{2}:\d{2}))?$' -or -not [datetimeoffset]::TryParse($item,[ref]$parsed)) { throw "Expected ISO date: $($property.Name)" }
        }
        default { throw "Local template supports flat scalar fields and arrays only; unsupported mapping type '$type' on $($property.Name)." }
      }
    }
  }
}

function Test-BulkFile([string]$Path, [string]$Index, [int]$ExpectedCount, [string]$MappingFile, [string]$IdField) {
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -eq 0 -or $bytes[$bytes.Length-1] -ne 10) { throw 'NDJSON must end with newline.' }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { throw 'NDJSON must be UTF-8 without BOM.' }
  $lines = [IO.File]::ReadAllLines($Path, [Text.UTF8Encoding]::new($false,$true))
  if ($lines.Count -ne $ExpectedCount*2) { throw 'NDJSON line count differs from expected document count.' }
  $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $properties = if ($MappingFile) { (Get-Content -LiteralPath $MappingFile -Raw -Encoding UTF8 | ConvertFrom-Json).mappings.properties } else { $null }
  if ($MappingFile -and -not $properties) { throw 'MappingFile must contain mappings.properties.' }
  for ($i=0; $i -lt $lines.Count; $i+=2) {
    $action = $lines[$i] | ConvertFrom-Json
    $doc = $lines[$i+1] | ConvertFrom-Json
    if ($doc -isnot [pscustomobject]) { throw "Source must be a JSON object at line $($i+2)." }
    if (@($action.PSObject.Properties).Count -ne 1 -or -not $action.index -or $action.index._index -cne $Index) { throw "Invalid action/index at line $($i+1)." }
    $id = [string]$action.index._id
    if ([string]::IsNullOrWhiteSpace($id) -or -not $ids.Add($id)) { throw "Empty or duplicate ID at line $($i+1)." }
    if ($IdField -and [string]$doc.$IdField -cne $id) { throw "Business ID does not match _id at line $($i+2)." }
    if ($properties) { Assert-DocumentMapping $doc $properties }
  }
  return $ids.Count
}
