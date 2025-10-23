# get-active.ps1
# Queries month-by-month to avoid overloading the endpoint.
# Output: active.json (array of { completionDate, registrationDate })

param(
    [string]$BaseUrl = 'https://api-debtcollection.utv.kredinor.int',
    [string]$ServicePurchaserId = '8b23ef0c-dc1a-088d-11e0-f8d33c2489e4',
    [string]$IntegrationName = 'TestIntegrasjon',
    [datetime]$From = [datetime]'2020-09-01',
    [datetime]$ToExclusive = [datetime]'2025-10-01'
)

$headers = @{
    'Accept'                     = 'application/json'
    'X-Kredinor-IntegrationName' = $IntegrationName
}

$all = New-Object System.Collections.Generic.List[object]
$cursor = $From

while ($cursor -lt $ToExclusive) {
    $start = $cursor.ToString('yyyy-MM-dd')
    $end   = $cursor.AddMonths(1).ToString('yyyy-MM-dd')

    $url = "$BaseUrl/servicepurchaser/$ServicePurchaserId/collectionorders/active?dateFrom=$start&dateTo=$end"
    Write-Host "Fetching active $start → $end ..." -ForegroundColor Cyan

    # Simple retry with exponential backoff
    $attempt = 0
    $maxAttempts = 3
    $response = $null
    do {
        try {
            $attempt++
            $response = Invoke-RestMethod -Method GET -Uri $url -Headers $headers -TimeoutSec 120
        } catch {
            if ($attempt -lt $maxAttempts) {
                $delay = [int][math]::Min(60, [math]::Pow(2, $attempt))
                Write-Warning "Attempt $attempt failed ($($_.Exception.Message)). Retrying in $delay s..."
                Start-Sleep -Seconds $delay
            } else {
                Write-Error "Failed $start → $end after $maxAttempts attempts. Skipping this month."
            }
        }
    } while (-not $response -and $attempt -lt $maxAttempts)

    if ($response) {
        foreach ($item in $response) {
            # These may be missing/null on active cases; keep keys and allow nulls.
            $completionDate = $null
            if ($item.PSObject.Properties['completionDate']) { $completionDate = $item.completionDate }

            $registrationDate = $null
            if ($item.PSObject.Properties['registrationDate']) { $registrationDate = $item.registrationDate }

            $all.Add([pscustomobject]@{
                completionDate   = $completionDate
                registrationDate = $registrationDate
            })
        }
        Write-Host ("  + {0} rows" -f $response.Count) -ForegroundColor DarkGray
    }

    $cursor = $cursor.AddMonths(1)
}

# Write to active.json as a single JSON array
$outPath = Join-Path -Path (Get-Location) -ChildPath 'active.json'
$all | ConvertTo-Json -Depth 3 | Set-Content -Path $outPath -Encoding UTF8

Write-Host "Done. Wrote $($all.Count) rows to $outPath" -ForegroundColor Green
