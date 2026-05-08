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

    Ensure-IPPSSession

    # region find search
    try {
        $srch = Get-ComplianceSearch -Name $SearchName -ErrorAction Stop
        Write-Verbose "Search instance found"
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Compliance search $SearchName could not be found.",
            $_.Exception
        )
    }

    if ($srch.Status -ne 'Completed') {
        throw [System.InvalidOperationException]::new(
            "Compliance search $SearchName is in state '$($srch.Status)' and cannot be purged until it successfully completes."
        )
    }

    if ($srch.Items -eq 0) {
        Write-Verbose "Compliance search $SearchName returned no results"
        return
    }
    # endregion

    # region purge
    $maxPasses = 100
    $stallLimit = 5
    $stall = 0

    if ($PSCmdlet.ShouldProcess(
        "Compliance search $SearchName",
        "Create $purgeType purge action"
        )
    ) {
        for ($pass = 0; $pass -lt $maxPasses; $pass++) {
            New-ComplianceSearchAction `
                -SearchName $SearchName `
                -Purge `
                -PurgeType $purgeType `
                -ErrorAction Stop
            $srch = Run-PurviewEmailSearch -Search $srch

            if ($srch.Items -eq 0) {
                Write-Verbose "Purge action completed successfully."
                return
            }

            if ($srch.Items -eq $prv) {
                $stall++

                if ($stall -ge $stallLimit) {
                    throw [System.InvalidOperationException]::new(
                        "Purge made no progress for $stall consecutive passes. Remaining hits: $($srch.Items). Aborted."
                    )
                }
            }
            else {
                $stall = 0
            }

            $prv = $srch.Items
        }
    }

    throw [System.TimeoutException]::new(
        "The operation timed out after $maxPasses attempts."
    )
    # endregion
}