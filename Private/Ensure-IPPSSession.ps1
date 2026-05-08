function Ensure-IPPSSession {
    [CmdletBinding()]
    param()

    # region module ensurance
    if (-not (Get-Module -Name ExchangeOnlineManagement)) {
        Write-Verbose "ExchangeOnlineManagement module not imported."
        if (-not (Get-Module -Name ExchangeOnlineManagement -ListAvailable)) {
            throw [System.IO.FileNotFoundException]::new(
                "ExchangeOnlineManagement module required for this action. Please install it with `"Install-Module ExchangeOnlineManagement`"",
                "ExchangeOnlineManagement"
            )
        }

        Import-Module -Name ExchangeOnlineManagement -ErrorAction Stop
    }
    # endregion

    # region connection
    try {
        Get-OrganizationConfig -ErrorAction Stop | Out-Null
        Write-Verbose "Pre-existing connection to ExchangeOnline service discovered"
    }
    catch {
        Write-Warning "Connection to Exchange Online service required to continue. Expect a prompt."
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    }

    try {
        Get-ComplianceSearch -ResultSize 1 -ErrorAction Stop | Out-Null
        Write-Verbose "Pre-exisiting connection to Purview eDiscovery service found"
    }
    catch {
        Write-Warning "Connection to Purview eDiscovery service is required to continue. Expect a prompt."
        Connect-IPPSSession -ShowBanner:$false -EnableSearchOnlySession

        try {
            Get-ComplianceSearch -ResultSize 1 -ErrorAction Stop | Out-Null
        }
        catch {
            throw [System.UnauthorizedAccessException]::new(
                "Connected account lacks required Purview eDiscovery permissions.",
                $_.Exception
            )
        }
    }
    # endregion
}