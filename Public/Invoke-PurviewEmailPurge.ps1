function Invoke-PurviewEmailPurge{
    <#
    .SYNOPSIS
    Executes a Purview Compliance Search purge action and waits for completion.

    .DESCRIPTION
    Invoke-PurviewEmailPurge performs one or more Purview eDiscovery purge actions
    against an existing, completed Compliance Search. The function waits for each
    purge action to finish, re-runs the search to verify progress, and repeats until
    no matching items remain or progress stalls.

    This cmdlet enforces safe execution by requiring the Compliance Search to be in
    a Completed state and by prompting for confirmation before performing purge operations.

    SoftDelete is used by default. Use -HardDelete with caution, as it permanently
    removes items and cannot be undone.

    .PARAMETER SearchName
    The name of an existing Purview Compliance Search to purge.
    The search must exist and must have completed successfully before this cmdlet
    is executed.

    .PARAMETER HardDelete
    Specifies that matching items should be permanently deleted.
    If not specified, items are soft-deleted and moved to the Recoverable Items folder.
    HardDelete operations cannot be reversed.

    .INPUTS
    System.String
    Microsoft.Exchange.Management.ComplianceSearch

    .OUTPUTS
    Microsoft.Exchange.Management.ComplianceSearch
    Returns the final Compliance Search object after purge completion.

    .EXAMPLE
    Invoke-PurviewEMailPurge -SearchName IncidentSearch001

    Performs a soft-delete purge of all items returned by the compliance search
    named IncidentSearch001.
    .EXAMPLE
    Get-ComplianceSearch -Identity IncidentSearch002 | Invoke-PurviewEmailPurge -HardDelete

    Permanently deletes all items returned by the compliance search
    provided via the pipeline after user confirmation.

    .NOTES
    This cmdlet assumes access to the ExchangeOnlineManagement module.
    If not present, an error will halt the function.

    Purge actions run asynchronously and may take a significant amount of time,
    especially when many mailboxes or large numbers of items are involved.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Name", "Identity")]
        [ValidateNotNullOrWhiteSpace()]
        [string]$SearchName,

        [Parameter()]
        [switch]$HardDelete
    )

    begin {
        Ensure-PurviewSession
    }

    process {
        if ($HardDelete) {
                $purgeType = 'HardDelete'
            }
        else {
            $purgeType = 'SoftDelete'
        }
        

        # region find search
        try {
            Write-Verbose "Searching for compliance search results"
            $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
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
        if ($purgeType -eq 'HardDelete') {
            Write-Warning "HardDelete permanently removes items and cannot be undone."
        }
        if (-not ($PSCmdlet.ShouldProcess(
            "Compliance search $SearchName",
            "Create $purgeType purge action"
            ))
        ) {
            Write-Warning "Operation declined by user."
            return
        }

        $maxPasses  = 100
        $stallLimit = 3
        $stall      = 0
        $prv        = -1 # temp assignment

        for ($pass = 0; $pass -lt $maxPasses; $pass++) {
            Write-Verbose "Starting purge pass $($pass + 1) of $maxPasses"
            $action = New-ComplianceSearchAction `
                -SearchName $SearchName `
                -Purge `
                -PurgeType $purgeType `
                -Confirm:$false `
                -ErrorAction Stop
            Wait-PurviewComplianceSearchAction -ActionIdentity $action.Identity

            Write-Verbose "Starting search for updated results"
            $search = Invoke-PurviewEmailSearch -SearchName $SearchName


            if ($search.Items -eq $prv) {
                Write-Verbose "No additional purges have been noted on pass $($pass + 1)"
                $stall++

                if ($stall -ge $stallLimit) {
                    if ($search.Items -eq 0) {
                        Write-Verbose "Search index converged at zero items"
                    }
                    else {
                        Write-Verbose "Search index converged with $($search.Items) items (likely already purged)"
                    }

                    return
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

        return $search
    }
}