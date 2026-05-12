function Invoke-PurviewEmailSearch {
    <#
    .SYNOPSIS
    Starts a Purview Compliance Search and waits for completion.

    .DESCRIPTION
    Invoke-PurviewEmailSearch starts an existing Purview Compliance Search,
    waits for the asynchronous search operation to complete, and
    returns the updated Compliance Search object.

    The cmdlet does not create or modify searches beyond execution and enforces
    successful completion before returning.

    .PARAMETER SearchName
    The name of an existing Purview Compliance Search to execute.
    The search must exist for it to be executed.

    .INPUTS
    System.String
    Microsoft.Exchange.Management.ComplianceSearch

    .OUTPUTS
    Microsoft.Exchange.Management.ComplianceSearch

    .EXAMPLE
    Invoke-PurviewEmailSearch -SearchName IncidentSearch001

    Performs the search specified by the KQL query within
    the Compliance Search IncidentSearch001

    .EXAMPLE
    Get-ComplianceSearch -Identity IncidentSearch002 | Invoke-PurviewEmailSearch

    Executes the search of the Compliance Search provided
    via the pipeline

    .NOTES
    This cmdlet assumes access to the ExchangeOnlineManagement module.
    If not present, an error will halt the function.

    Search actions run asynchronously and may take a significant amount of time,
    especially when many mailboxes or large numbers of items are involved.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Name", "Identity")]
        [string]$SearchName
    )

    begin {
        Ensure-PurviewSession
    }

    process {
        # region get search
        try {
            Write-Verbose "Searching for compliance search instance"
            $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
        }
        catch {
            throw [System.InvalidOperationException]::new(
                "Couldn't find search with name: $SearchName",
                $_.Exception
            )
        }
        # endregion

        # region search
        Write-Verbose "Beginning async compliance search"
        Start-ComplianceSearch -Identity $SearchName -ErrorAction Stop

        try {
            Write-Verbose "Waiting for search completion"
            Wait-PurviewComplianceSearch -SearchName $SearchName
        }
        catch [System.Management.Automation.PipelineStoppedException] {
            Write-Host ""
            Write-Warning "Search cancelled by user."
            return
        }

        $search = Get-ComplianceSearch -Identity $SearchName
        if ($search.Status -eq 'Failed') {
            throw [System.InvalidOperationException]::new(
                "Compliance search '$($search.Name)' completed with status 'Failed'. Check Purview for details."
            )
        }
        # endregion

        return $search
    }
}