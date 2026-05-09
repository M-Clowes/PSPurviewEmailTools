function New-PurviewEmailSearch {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [Alias("Sender", "Author", "SenderUPN", "From", "SentFrom", "SentBy")]
        [ValidateNotNullOrWhiteSpace()]
        [string]$SenderAddress,

        [Parameter(Position = 1)]
        [Alias("RecipientAddress", "Recipient", "Recipients", "RecipientUPN", "RecipientUPNs", "To", "CC", "RecievedBy")]
        [ValidateNotNullOrWhiteSpace()]
        [string[]]$RecipientAddresses,

        [Parameter(Position = 2)]
        [Alias("Subject", "Header", "Title")]
        [ValidateNotNullOrWhiteSpace()]
        [string]$SubjectBody,

        [Parameter()]
        [Alias("Start", "After" , "SentTime", "SentAt")]
        [datetime]$StartDate,

        [Parameter()]
        [Alias("End", "Before" , "Until")]
        [datetime]$EndDate,

        [Parameter()]
        [switch]$Search,

        [Parameter()]
        [switch]$PassThru
    )

    # region param checks
    if (-not ($SenderAddress -and $RecipientAddresses -and $SubjectBody)) {
        throw [System.ArgumentException]::new(
            "At least one of SenderAddress, RecipientAddresses or SubjectBody must be defined."
        )
    }

    if (($SenderAddress -and $RecipientAddresses) -and ($RecipientAddresses -contains $SenderAddress)) {
        throw [System.ArgumentException]::new(
            "SenderAddress cannot be set as a RecipientAddress.",
            "SenderAddress"
        )
    }

    if ($StartDate) {
        $StartDate = $StartDate.AddDays(-1) # Add inclusive range
    }
    if ($EndDate) {
        if ($EndDate.Date -ne (Get-Date).Date) {
            $EndDate = $EndDate.AddDays(1) # Add inclusive range
        }
    }
    if (($StartDate -and $EndDate) -and ($StartDate -ge $EndDate)) {
        throw [System.ArgumentException]::new(
            "StartDate cannot exceed EndDate.",
            "StartDate"
        )
    }
    # endregion

    Ensure-IPPSSession

    # region KQL
    $qryParts = [System.Collections.Generic.List[string]]::new()

    if ($SenderAddress) {
        $qryParts.Add("(SenderAuthor=$SenderAddress)")
    }

    if ($RecipientAddresses) {
        $rcvrParts = [System.Collections.Generic.List[string]]::new()
        foreach ($rcvr in $RecipientAddresses) {
            $rcvrParts.Add("(Recipients:$rcvr)")
        }

        $qry = $rcvrParts -join " OR "
        $qryParts.Add("($qry)")
    }

    if ($SubjectBody) {
        $qryParts.Add("SubjectTitle=`"$SubjectBody`"")
    }

    if ($StartDate) {
        $qryParts.Add("Date>$($StartDate.Date)")
    }

    if ($EndDate) {
        $qryParts.Add("Date<$($EndDate.Date)")
    }

    $qryBody = $qryParts -join " AND "
    # endregion

    # region create search
    $srchName = "New-PurviewEmailSearch_" + [guid]::NewGuid().ToString()
    try {
        $srch = New-ComplianceSearch `
            -Name $srchName `
            -ExchangeLocation All `
            -ContentMatchQuery $qryBody `
        | Out-Null
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Failed to create compliance search '$srchName'.",
            $_.Exception
        )
    }
    # endregion

    # region search
    if ($Search) {
        $srch = Run-PurviewEmailSearch -Search $srch
    }
    # endregion

    # region output
    if ($PassThru) {
        return [PSCustomObject]@{
            SearchName = $srchName
            Status     = $srch.Status
            Succeeded  = $($srch.Status -eq 'Completed')
        }
    }
    else {
        return $srchName
    }
    # endregion
}
