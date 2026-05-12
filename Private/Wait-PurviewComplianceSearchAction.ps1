function Wait-PurviewComplianceSearchAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias()]
        [ValidateNotNullOrWhiteSpace()]
        [string]$ActionIdentity,

        [Parameter(Position = 1)]
        [Alias()]
        [ValidateNotNullOrWhiteSpace()]
        [string]$Message = "Purging..."
    )

    try {
        $action = Get-ComplianceSearchAction -Identity $action.Identity
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Could not find Compliance Search Action: $ActionIdentity.",
            $_.Exception
        )
    }

    $frames    = '/', '-', '\', '|'
    $idx       = 0
    $startTime = Get-Date
    $lastPoll  = Get-Date
    $pollRate  = [TimeSpan]::FromSeconds(15)
    $timeout   = [TimeSpan]::FromMinutes(60)
    $spinRate  = 100 # milliseconds
    $warn      = $false

    do {
        $now = Get-Date
        $elapsed = $now - $startTime
        if ($warn) {
            Write-Host "`r[$($now.ToString("HH:mm:ss"))] $Message ($([int]$elapsed.TotalMinutes)min) $($frames[$idx % $frames.Count])" -NoNewLine
        }
        else {
            Write-Host "`r[$($now.ToString("HH:mm:ss"))] $Message $($frames[$idx % $frames.Count])" -NoNewLine
        }

        if (($now - $lastPoll) -ge $pollRate) {
            $action = Get-ComplianceSearchAction -Identity $action.Identity
            $lastPoll = $now
        }

        if (-not $warn -and ($elapsed -ge [TimeSpan]::FromMinutes(1))) {
            Write-Host "`rWe apologise for the delay. Each purge action may take up to 60 minutes."
            $warn = $true
        }

        if ($elapsed -ge $timeout) {
            throw [System.TimeoutException]::new(
                "Operation timed out after $([int]$elapsed.TotalMinutes) minutes."
            )
        }

        $idx++
        Start-Sleep -Milliseconds $spinRate
    } while ($action.Status -notin @('Completed', 'Failed'))

    Write-Host "`r[$($now.ToString("HH:mm:ss"))] $Message " -NoNewLine
    if ($warn) {
        Write-Host "($([int]$elapsed.TotalMinutes)min) " -NoNewLine
    }
    Write-Host -ForegroundColor DarkGreen "Complete."
}