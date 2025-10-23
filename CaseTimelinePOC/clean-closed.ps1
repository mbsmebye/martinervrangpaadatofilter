# clean-closed.ps1  (no backups)
param(
    [string]$Path = 'closed.json',
    [datetime]$MinRegistrationDate = [datetime]'2020-09-01'
)

# Resolve 'closed' -> 'closed.json' if needed
if (-not (Test-Path $Path)) {
    if (Test-Path "$Path.json") { $Path = "$Path.json" }
    else { throw "File not found: $Path (or $Path.json)" }
}

# Load and parse
$raw  = Get-Content -Raw -Path $Path
$data = $raw | ConvertFrom-Json
if ($null -eq $data) { Write-Host "Nothing to clean (empty JSON)."; exit 0 }

# Normalize to array
if ($data -isnot [System.Collections.IEnumerable]) { $data = @($data) }

# Keep only entries with registrationDate >= cutoff
$filtered = $data | Where-Object {
    $_.PSObject.Properties['registrationDate'] -and
            ([datetime]$_.registrationDate -ge $MinRegistrationDate)
}

# Overwrite file
$filtered | ConvertTo-Json -Depth 4 | Set-Content -Path $Path -Encoding UTF8
Write-Host "Cleaned. Kept $($filtered.Count) of $($data.Count). Overwrote $Path." -ForegroundColor Green
