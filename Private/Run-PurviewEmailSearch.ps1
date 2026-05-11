function Run-PurviewEmailSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$SearchName
    )

    try {
        $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Couldn't find search with name: $SearchName",
            $_.Exception
        )
    }

    Start-ComplianceSearch -Identity $SearchName -ErrorAction Stop

    $frames    = '/', '-', '\', '|'
    $idx       = 0
    $startTime = Get-Date
    $lastPoll  = Get-Date
    $pollRate  = [TimeSpan]::FromSeconds(15)
    $timeout   = [TimeSpan]::FromMinutes(30)
    $spinRate  = 100 # milliseconds
    $warn      = $false

    try {
        while ($search.Status -notin @('Completed', 'Failed')) {
            $now    = Get-Date
            $elapsed = $now - $startTime

            if ($warn) {
                $msg = "`r[$($now.ToString("HH:mm:ss"))] Searching... ($([int]$elapsed.TotalMinutes)min) $($frames[$idx % $frames.Count])"
            }
            else {
                $msg = "`r[$($now.ToString("HH:mm:ss"))] Searching... $($frames[$idx % $frames.Count])"
            }

            Write-Host $msg -NoNewLine
            $idx++

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

            Start-Sleep -Milliseconds $spinRate
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        Write-Host ""
        Write-Warning "Search canclled by user."
        return
    }

    if ($search.Status -eq 'Failed') {
        throw [System.InvalidOperationException]::new(
            "Compliance search '$($search.Name)' completed with status 'Failed'. Check Purview for details."
        )
    }

    Write-Host "`r[$($now.ToString("HH:mm:ss"))] Searching... " -NoNewline
    if ($warn) {
        Write-Host "($([int]$elapsed.TotalMinutes)min) " -NoNewLine
    }
    Write-Host -ForegroundColor DarkGreen "Complete."

    return $search
}