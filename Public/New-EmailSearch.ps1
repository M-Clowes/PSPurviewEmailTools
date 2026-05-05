function New-EmailSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$SubjectBody,

        [Parameter(Mandatory, Position = 1)]
        [datetime]$StartDate,

        [Parameter(Position = 2)]
        [datetime]$EndDate = (Get-Date),

        [Parameter()]
        [string]$SenderAddress,

        [Parameter()]
        [string]$RecipientAddress,

        [Parameter()]
        [switch]$AppAuthentication,

        [Parameter()]
        [switch]$PassThru
    )

    # region logic guard
    if ($StartDate -gt $EndDate) {
        Write-Verbose "Invalid operation. StartDate cannot be greater than EndDate"
        throw "StartDate must be earlier than EndDate"
    }
    # endregion

    # region connect
    if ($AppAuthentication) {
        Write-Verbose "Connecting to Purview"
        Connect-PSPurview -EnableSearchOnlySession -AppAuthentication
    }
    else {
        Write-Host "Connecting to your tenant..."
        Connect-PSPurview -EnableSearchOnlySession
    }
    # endregion

    Write-Verbose "Building KQL Query"
    $cls = @()

    $cls += "Subject:`"$SubjectBody`""
    $cls += "Sent>=$($StartDate.ToString('yyyy-MM-dd'))"
    $cls += "Sent<=$($EndDate.ToString('yyyy-MM-dd'))"

    if ($SenderAddress) {
        Write-Verbose "Sender address specified"
        $cls += "From: `"$SenderAddress`""
    }

    if ($RecipientAddress) {
        Write-Verbose "Recipient address specified"
        $cls += "(To: `"$RecipientAddress`" OR Cc:`"$RecipientAddress`")"
    }

    Write-Verbose "Joining query strings"
    $qry = $cls -Join ' AND '
    # endregion

    # region search
    $srchNm = "GetEmail_$([Guid]::NewGuid().ToString())"

    Write-Verbose "Building search body"
    New-ComplianceSearch `
        -Name $srchNm `
        -ExchangeLocation All `
        -ContentMatchQuery $qry `
        -ErrorAction Stop

    Write-Verbose "Executing search"
    Start-ComplianceSearch -Identity $srchNm -ErrorAction Stop
    
    $spnr = '/', '-', '\', '|'
    $spnrIdx = 0

    $elapsed = 0
    $pollRate = 15 # seconds
    do {
        if (($elapsed % $pollRate) -eq 0) {
            $srch = Get-ComplianceSearch -Identity $srchNm
        }
        Write-Host "`rWaiting for search completion... $($spnr[$spnrIdx])" -NoNewline
        Start-Sleep -Seconds 1
        $spnrIdx = ($spnrIdx + 1) % $spnr.Count
    }
    while ($srch.Status -in @('Starting', 'InProgress'))

    if ($srch.Status -ne 'Completed') {
        Write-Verbose "Seach ended with status: $($srch.Status)"
        throw "Search did not complete successfully."
    }
    Write-Host "`rSearch completed."
    # endregion

    # region output
    if ($PassThru) {
        [PSCustomObject]@{
            SearchName = $srch.Name
            Status     = $srch.Status
            Items      = $srch.Items
            CreatedAt  = $srch.CreatedTime
        }
    }
    else {
        $srch.Name
    }
    # endregion
}