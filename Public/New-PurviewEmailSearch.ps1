function New-PurviewEmailSearch {
    <#
    .SYNOPSIS
    Creates a Purview Compliance Search for email content and optionally executes or purges it.

    .DESCRIPTION
    New-PurviewEmailSearch constructs and creates a new Purview eDiscovery Compliance Search
    based on sneder, recipient, subject and date criteria. The cmdlet creates the search
    definition, and-if specified-can execute the search and perform purge actions using
    companion cmdlets.

    Mailbox scope is derived safely:
    - By default, specifying recipients limits the search to those recipients' mailboxes.
    - Use -SearchAllMailboxes to explicitly apply recipient filtering across all mailboxes.

    This cmdlet does not implicitly execute or purge searches unless explicitly instructed
    via -ExecuteSearch and -ExecutePurge. Purge operations require the search to have been
    executed and completed successfully.

    .PARAMETER SenderAddress
    Specifies the sender address used to filter matching email messages.

    .PARAMETER RecipientAddresses
    Specifies one or more recipient addresses used to filter matching email messages.
    By default, these recipients also determine the mailbox scop
    unless -SearchAllMailboxes is specified.

    .PARAMETER SubjectBody
    Specifies text to match against the email subject.
    The value is sanitized for safe KQL usage to prevent malformed queries

    .PARAMETER StartDate
    Specifies the earliest date to include in the filter for matching email messages.
    The value cannot be in the future.

    .PARAMETER EndDate
    Specifies the latest date to include in the filter for matching email messages.
    The search uses non-inclusive date boundaries to safely include all messages
    from the specified day.
    This value cannot be in the future.

    .PARAMETER SearchAllMailboxes
    Expands the search scope to all mailboxes, even when recipient filters are specified.
    Use with caution.

    .PARAMETER ExecuteSearch
    Executes the ComplianceSearch immediately after creation and waits for completion.

    .PARAMETER ExecutePurge
    Purges items returned by the search after successful execution.
    This parameter requires -ExecuteSearch.

    .PARAMETER PassThru
    Returns the Microsoft.Exchange.Management.ComplianceSearch object
    representing the newly created Compliance Search instead of only
    the search name.
    
    .INPUTS
    None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
    System.String
    Microsoft.Exchange.Management.ComplianceSearch

    When -PassThru is specified, the cmdlet returns the Compliance Search object.
    Otherwise, it returns the name of the created search.

    .EXAMPLE
    New-PurviewEmailSearch -SenderAddress a@contoso.com -SubjectBody "Quarterly Report"

    Creates a new Compliance Search matching messages sent by a@contoso.com
    with "Quarterly Report" in the subject.

    .EXAMPLE
    New-PurviewEmailSearch `
        -RecipientAddresses b@contoso.com, c@contoso.com `
        -SubjectBody "Incident" `
        -StartDate "2026-05-01" `
        -EndDate "2026-05-12" `
        -ExecuteSearch

    Creates and executes a Compliance Search for messages sent to
    b@contoso.com and c@contoso.com matching the specified subject and date range.

    .EXAMPLE
    New-PurviewEmailSearch `
        -RecipientAddresses d@contoso.com `
        -SubjectBody "Confidential" `
        -SearchAllMailboxes `
        -ExecuteSearch `
        -ExecutePurge

    Creates a Compliance Search across all mailboxes for messages sent to d@contoso.com,
    executes the search, and purges the results after confirmation.

    .NOTES
    This cmdlet assumes access to the ExchangeOnlineManagement module.
    If not present, an error will halt the function.

    Date filters use whole-day semantics and non-inclusive end-boundaries to
    avoid time-zone and daylight saving issues.
    
    For advanced lifecycle control, use Invoke-PurviewEmailSearch and
    Invoke-PurviewEmailPurge directly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [Alias("Sender", "Author", "SenderAuthor", "SenderUPN", "From", "SentFrom", "SentBy")]
        [ValidateNotNullOrWhiteSpace()]
        [string]$SenderAddress,

        [Parameter(Position = 1)]
        [Alias("RecipientAddress", "Recipient", "Recipients", "RecipientUPN", "RecipientUPNs", "To", "CC", "RecievedBy")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            foreach ($val in $_) {
                if ([string]::IsNullOrWhiteSpace($val)) {
                    throw [System.ArgumentException]::new(
                        "Recipient address cannot be null, empty or whitespace.",
                        "RecipientAddresses"
                    )
                }
            }
            $true
        })]
        [string[]]$RecipientAddresses,

        [Parameter(Position = 2)]
        [Alias("Subject", "Header", "Title")]
        [ValidateNotNullOrWhitespace()]
        [string]$SubjectBody,

        [Parameter()]
        [Alias("Start", "After" , "SentTime", "SentAt")]
        [ValidateScript({
            if ($_ -gt (Get-Date)) {
                throw [System.ArgumentException]::new(
                    "StartDate cannot be in the future.",
                    "StartDate"
                )
            }
        })]
        [datetime]$StartDate,

        [Parameter()]
        [Alias("End", "Before" , "Until")]
        [ValidateScript({
            if ($_ -gt (Get-Date)) {
                throw [System.ArgumentException]::new(
                    "EndDate cannot be in the future.",
                    "EndDate"
                )
            }
        })]
        [datetime]$EndDate,

        [Parameter()]
        [switch]$SearchAllMailboxes,

        [Parameter()]
        [Alias("Search")]
        [switch]$ExecuteSearch,

        [Parameter()]
        [Alias("Purge")]
        [switch]$ExecutePurge,

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

    if (($StartDate -and $EndDate) -and ($StartDate -ge $EndDate)) {
        throw [System.ArgumentException]::new(
            "StartDate cannot exceed EndDate.",
            "StartDate"
        )
    }

    if ($ExecutePurge -and -not $ExecuteSearch) {
        throw [System.ArgumentException]::new(
            "Cannot purge a search without running it. Use -ExecuteSearch or run cmdlets separately",
            "ExecutePurge"
        )
    }

    if ($SearchAllMailboxes -or -not $RecipientAddresses) {
        $exchangeLocation = 'All'
    }
    else {
        $exchangeLocation = $RecipientAddresses
    }
    # endregion

    Ensure-PurviewSession

    # region KQL
    $qryParts = [System.Collections.Generic.List[string]]::new()

    if ($SenderAddress) {
        Write-Verbose "Adding SenderAddress: $SenderAddress"
        $qryParts.Add("(SenderAuthor=$SenderAddress)")
    }

    if ($RecipientAddresses) {
        $rcvrParts = [System.Collections.Generic.List[string]]::new()
        foreach ($rcvr in $RecipientAddresses) {
            Write-Verbose "Adding RecipientAddress: $rcvr"
            $rcvrParts.Add("(Recipients:$rcvr)")
        }

        $qry = $rcvrParts -join " OR "
        $qryParts.Add("($qry)")
    }

    if ($SubjectBody) {
        $kqlSjt = ConvertTo-KqlSafeString $SubjectBody
        Write-Verbose "Adding SubjectBody: $kqlSjt"
        $qryParts.Add("(SubjectTitle=`"$kqlSjt`")")
    }

    if ($StartDate) {
        Write-Verbose "Adding StartDate: $StartDate"
        $qryParts.Add("(Date>=$($StartDate.ToString("yyyy-MM-dd")))")
    }

    if ($EndDate) {
        $endExclusive = $EndDate.Date.AddDays(1)
        Write-Verbose "Adding EndDate: $exclusiveEnd"
        $qryParts.Add("(Date<$($endExclusive.ToString("yyyy-MM-dd")))")
    }

    $qryBody = $qryParts -join " AND "
    # endregion

    # region create search
    $srchName = "PowerShellPurviewEmailSearch_" + [guid]::NewGuid().ToString()
    try {
        Write-Verbose "Attempting to create compliance search: $srchName"
        New-ComplianceSearch `
            -Name $srchName `
            -ExchangeLocation $exchangeLocation `
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
    if ($ExecuteSearch) {
        Invoke-PurviewEmailSearch -SearchName $srchName
    }
    # endregion

    # region purge
    if ($ExecutePurge) {
        Invoke-PurviewEmailPurge -SearchName $srchName
    }
    # endregion

    # region output
    if ($PassThru) {
        $search = Get-ComplianceSearch -Identity $srchName
        return $search
    }
    else {
        return $srchName
    }
    # endregion
}