function Wait-PurviewComplianceSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias()]
        [ValidateNotNullOrWhiteSpace()]
        [string]$SearchName,

        [Parameter(Position = 1)]
        [Alias()]
        [ValidateNotNullOrWhiteSpace()]
        [string]$Message = "Searching..."
    )

    try {
        $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Couldn't find Compliance Search named: $SearchName",
            $_.Exception
        )
    }

    $frames    = '/', '-', '\', '|'
    $idx       = 0
    $startTime = Get-Date
    $lastPoll  = Get-Date
    $pollRate  = [TimeSpan]::FromSeconds(15)
    $timeout   = [TimeSpan]::FromMinutes(30)
    $spinRate  = 100 # milliseconds
    $warn      = $false

    do {
        $now     = Get-Date
        $elapsed = $now - $startTime
        if ($warn) {
            Write-Host "`r[$($now.ToString("HH:mm:ss"))] $Message ($([int]$elapsed.TotalMinutes)min) $($frames[$idx % $frames.Count])" -NoNewLine
        }
        else {
            Write-Host "`r[$($now.ToString("HH:mm:ss"))] $Message $($frames[$idx % $frames.Count])" -NoNewLine
        }

        if (($now - $lastPoll) -ge $pollRate) {
            $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
            $lastPoll = $now
        }

        if (-not $warn -and ($elapsed -ge [TimeSpan]::FromMinutes(1))) {
            Write-Host "`rWe apologise for the delay. Purview eDiscovery searches may take up to 30 minutes depending on scope."
            $warn = $true
        }

        if ($elapsed -ge $timeout) {
            throw [System.TimeoutException]::new(
                "Operation timed out after $([int]$elapsed.TotalMinutes) minutes"
            )
        }

        $idx++
        Start-Sleep -Milliseconds $spinRate
    } while ($search.Status -notin @('Completed', 'Failed'))

    Write-Host "`r[$($now.ToString("HH:mm:ss"))] $Message " -NoNewLine
    if ($warn) {
        Write-Host "($([int]$elapsed.TotalMinutes)min) " -NoNewLine
    }
    Write-Host -ForegroundColor DarkGreen "Complete."
}