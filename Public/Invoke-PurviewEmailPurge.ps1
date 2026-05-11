function Invoke-PurviewEmailPurge{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias("Name")]
        [ValidateNotNullOrWhiteSpace()]
        [string]$SearchName,

        [Parameter()]
        [switch]$HardDelete
    )

    if ($HardDelete) {
        $purgeType = 'HardDelete'
    }
    else {
        $purgeType = 'SoftDelete'
    }

    Ensure-IPPSSession # Creates ExOl- and IPPS-Session if not already present + checks relevant perms

    # region find search
    try {
        $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
        Write-Verbose "Search instance found"
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Compliance search $SearchName could not be found.",
            $_.Exception
        )
    }

    if ($search.Status -ne 'Completed') {
        throw [System.InvalidOperationException]::new(
            "Compliance search $SearchName is in state '$($search.Status)' and cannot be purged until it successfully completes."
        )
    }

    if ($search.Items -eq 0) {
        Write-Verbose "Compliance search $SearchName returned no results"
        return
    }
    # endregion

    # region purge
    if (-not ($PSCmdlet.ShouldProcess(
        "Compliance search $SearchName",
        "Create $purgeType purge action"
        ))
    ) {
        Write-Warning "Operation declined by user."
        return
    }

    $maxPasses  = 100
    $stallLimit = 5
    $stall      = 0
    $frames     = '/', '-', '\', '|'
    $spinRate   = 100 # milliseconds
    $pollRate   = [TimeSpan]::FromSeconds(15)
    $timeout    = [TimeSpan]::FromMinutes(30)
    $prv        = -1 # temp assignment

    for ($pass = 0; $pass -lt $maxPasses; $pass++) {
        $lastPoll  = Get-Date
        $startTime = Get-Date
        $warn      = $false
        $idx       = 0

        $action = New-ComplianceSearchAction `
            -SearchName $SearchName `
            -Purge `
            -PurgeType $purgeType `
            -Confirm:$false `
            -ErrorAction Stop
        $action = Get-ComplianceSearchAction -Identity $action.Identity

        while ($action.Status -notin @('Completed', 'Failed')) {
            $now = Get-Date
            $elapsed = $now - $startTime
            if ($warn) {
                $msg = "`r[$($now.ToString("HH:mm:ss"))] Purging... ($([int]$elapsed.TotalMinutes)) $($frames[$idx % $frames.Count])"
            }
            else {
                $msg = "`r[$($now.ToString("HH:mm:ss"))] Purging... $($frames[$idx % $frames.Count])"
            }

            if (($now - $lastPoll) -ge $pollRate) {
                $action = Get-ComplianceSearchAction -Identity $action.Identity
                $lastPoll = $now
            }

            if (-not $warn -and ($elapsed -ge [TimeSpan]::FromMinutes(1))) {
                Write-Host "`rWe apologise for the delay. Each purge action may take up to 30 minutes."
                $warn = $true
            }

            if ($elapsed -ge $timeout) {
                throw [System.TimeoutException]::new(
                    "Operation timed out after $([int]$elapsed.TotalMinutes) minutes."
                )
            }

            Write-Host $msg -NoNewLine
            $idx++
            Start-Sleep -Milliseconds $spinRate
        }

        $search = Run-PurviewEmailSearch -SearchName $SearchName

        if ($search.Items -eq 0) {
            Write-Verbose "Purge action completed successfully."
            return
        }

        if ($search.Items -eq $prv) {
                $stall++

            if ($stall -ge $stallLimit) {
                throw [System.InvalidOperationException]::new(
                    "Purge made no progress for $stall consecutive passes. Remaining hits: $($search.Items). Aborted."
                )
            }
        }
        else {
            $stall = 0
        }

        $prv = $search.Items
    }

    throw [System.TimeoutException]::new(
        "The operation timed out after $maxPasses attempts."
    )
    # endregion
}