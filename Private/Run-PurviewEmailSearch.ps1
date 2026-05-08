function Do-PurviewEmailSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [System.Management.Automation.PSCustomObject]$Search
    )

    $frames = '/', '-', '|', '\'
    $cntr = 0 # seconds
    $pollRate = 15 # seconds
    $timeout = 1800 # 30 mins

    do {
        if (($cntr % $pollRate) -eq 0) {
            $Search = Get-ComplianceSearch -Name $Search.Name -ErrorAction Stop
        }

        # t == 5 min
        if ($cntr -eq ($timeout / 6)) {
            Write-Host "`rWe apologise for the delay. Purview eDiscovery Searches may take up to 30 minutes."
        }

        if ($cntr -ge $timeout) {
            throw [System.TimeoutException]::new(
                "The operation timed out after 30 minutes. Check Purview for results."
            )
        }

        Write-Host "`rSearching... $($frames[$cntr % $frames.Count])" -NoNewLine
        $cntr++
        Start-Sleep -Seconds 1

    } while ($Search.Status -notin @('Completed', 'Failed'))

    if ($Search.Status -eq 'Failed') {
        throw [System.InvalidOperationException]::new(
            "Compliance search '$($Search.Name)' completed with status 'Failed'. Check Purview for details."
        )
    }

    Write-Host "`rSearching... " -NoNewline
    Write-Host -ForegroundColor DarkGreen "Done."

    return $Search
}