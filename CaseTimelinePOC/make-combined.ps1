# make-combined.ps1
param(
    [string]$ActivePath = 'active.json',
    [string]$ClosedPath = 'closed.json',
    [string]$OutPath    = 'wwwroot/combined.json',
    [int]$Total         = 350
)

$active = Get-Content -Raw $ActivePath | ConvertFrom-Json
$closed = Get-Content -Raw $ClosedPath | ConvertFrom-Json
if ($active -isnot [System.Collections.IEnumerable]) { $active=@($active) }
if ($closed -isnot [System.Collections.IEnumerable]) { $closed=@($closed) }

$na = $active.Count
$nc = $closed.Count
if ($na -eq 0 -and $nc -eq 0) { throw "Both files are empty." }

# Proportional split (round), then fix remainder to hit exactly $Total
$ka = [math]::Round($Total * ($na / ($na + $nc)))
$kc = $Total - $ka

# Guard against requesting more than available
if ($ka -gt $na) { $ka = $na; $kc = [math]::Min($Total - $ka, $nc) }
if ($kc -gt $nc) { $kc = $nc; $ka = [math]::Min($Total - $kc, $na) }

# Sample and keep only needed fields
$pickA = if ($ka -gt 0) { $active | Get-Random -Count $ka | Select-Object completionDate, registrationDate } else { @() }
$pickC = if ($kc -gt 0) { $closed | Get-Random -Count $kc | Select-Object completionDate, registrationDate } else { @() }

# Combine and shuffle
$combined = @($pickA + $pickC)
if ($combined.Count -lt $Total) {
    Write-Warning "Only $($combined.Count) available (limited by file sizes)."
}
$shuffled = $combined | Get-Random -Count $combined.Count

$shuffled | ConvertTo-Json -Depth 3 | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "Wrote $($shuffled.Count) entries to $OutPath (active=$ka, closed=$kc)" -ForegroundColor Green
