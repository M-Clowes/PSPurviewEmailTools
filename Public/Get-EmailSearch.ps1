function Get-EmailSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$SearchName,

        [Parameter()]
        [switch]$AppAuthentication,

        [Parameter()]
        [switch]$CsvOut
    )

    # region connect
    if ($AppAuthentication) {
        Write-Verbose "Connecting to Purview"
        Connect-PSPurview -AppAuthentication
    }
    else {
        Write-Host "Connecting to your tenant..."
        Connect-PSPurview
    }
    # endregion

    # region logic guard
    try {
        Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Verbose "Search with name $SearchName could not be accessed"
        throw "Compliance search '$SearchName' does not exist or is inaccessible"
    }
    # endregion

    # region preview
    Write-Verbose "Starting preview action"
    $prvwAct = New-ComplianceSearchAction `
        -SearchName $SearchName `
        -Preview `
        -ErrorAction Stop

    $spnr = '/', '-', '\', '|'
    $spnrIdx = 0

    $elapsed = 0
    $pollRate = 15 # seconds
    do {
        if (($elapsed % $pollRate) -eq 0) {
            $act = Get-ComplianceSearchAction -Identity $prvwAct.Identity
        }
        Write-Host "`rGathering results... $($spnr[$spnrIdx])" -NoNewline
        Start-Sleep -Seconds 1
        $spnrIdx = ($spnrIdx + 1) % $spnr.Count
    }
    while ($act.Status -in @('Starting', 'InProgress'))

    if ($act.Status -ne 'Completed') {
        Write-Verbose "Preview action ended with status: $($act.Status)"
        throw "Results could not be gathered successfully."
    }
    Write-Host "`rResults gathered."
    # endregion

    # region data formatting
    $prvwRslt = $act.PreviewResults
    
    Write-Verbose "Formatting result"
    $prvwBdy = foreach ($item in $prvwRslt) {
        [PSCustomObject]@{
            'Subject'   = $item.Subject
            'From'      = $item.From
            'To'        = ($item.To -Join ';')
            'CC'        = ($item.Cc -Join ';')
            'SentDate'  = $item.SentTime
            'MessageId' = $item.InternetMessageId
            'Snippet'   = $item.Snippet
        }
    }
    # endregion

    # region output
    if ($CsvOut) {
        Write-Verbose "Attempt to write to CSV"
        $csvPth = Join-Path $env:TEMP "$(Get-Date -Format 'yyyy.MM.dd_HH.mm.ss')-$($SearchName).csv"

        $prvwBdy | Export-Csv `
            -Path $csvPth `
            -NoTypeInformation `
            -Encoding UTF8
        Write-Verbose "CSV written to $csvPth"
    }

    $prvwBdy
    # endregion
}