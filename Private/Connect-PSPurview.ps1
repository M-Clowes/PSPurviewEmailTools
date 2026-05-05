function Connect-PSPurview {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$AppAuthentication,

        [Parameter()]
        [switch]$EnableSearchOnlySession
    )
    
    # region ExOl module
    if (-not (Get-Module ExchangeOnlineManagement)) {
        Write-Verbose "ExchangeOnlineManagement module not imported."
        if (-not (Get-Module ExchangeOnlineManagement -ListAvailable)) {
            Write-Verbose "ExchangeOnlineManagement module not present on this device."
            throw "ExchangeOnlineManagement module required. Please install it."
        }
        Write-Verbose "Importing module..."
        Import-Module ExchangeOnlineManagement
    }
    # endregion

    # region config
    if ($AppAuthentication) {
        Write-Verbose "Gathering app authentication details"
        $config = Get-Content "$PSScriptRoot\app_details.json" | ConvertFrom-Json
        if (-not ([string]::IsNullOrWhiteSpace($config.CertificateThumbprint))) {
            Write-Verbose "Certificate thumbprint found"
        }
        else {
            Write-Verbose "No authentication method provided in app details Json file"
            throw "Unable to authenticate: No method provided"
        }
    }
    # endregion

    # region ExOl connection
    Write-Verbose "Checking for pre-exisiting Exchange Online connection"
    try {
        Get-OrganizationConfig -ErrorAction Stop | Out-Null
        Write-Verbose "Exchange Online connection already exists"
    }
    catch {
        Write-Verbose "Attempting to connect to Exchange Online"
        if ($AppAuthentication) {
            Write-Verbose "Connecting via app authentication"
            Connect-ExchangeOnline `
                -AppId $config.AppId `
                -Organization $config.Organization `
                -CertificateThumbprint $config.CertificateThumbprint `
                -ShowBanner:$false
        }
        else {
            Write-Host -ForegroundColor Yellow -BackgroundColor Black "Exchange Online authorization needed. Expect a prompt."
            Connect-ExchangeOnline -ShowBanner:$false
        }

        Write-Verbose "Validating Exchange Online permissions"
        try {
            Get-OrganizationConfig -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Verbose "Insufficient permissions for Exchange Online"
            throw "Exchange Online permission validation failed: $($_.Exception.Message)"
        }
    }
    Write-Verbose "Connected to Exchange Online successfully"
    # endregion

    # region Purview connection
    Write-Verbose "Checking for pre-existing Purview connection"
    try {
        Get-ComplianceSearch -ResultSize 1 -ErrorAction Stop | Out-Null
        Write-Verbose "Purview connection already exists"
    }
    catch {
        Write-Verbose "Attempting to connect to IPPS Session"
        if ($AppAuthentication) {
            Write-Verbose "Connecting via app authentication"
            if ($EnableSearchOnlySession) {
                Write-Verbose "EnableSearchOnlySession specified"
                Connect-IPPSSession `
                    -AppId $config.AppId `
                    -Organization $config.Organization `
                    -CertificateThumbprint $config.CertificateThumbprint `
                    -EnableSearchOnlySession `
                    -ShowBanner:$false
            }
            else {
                Connect-IPPSSession `
                    -AppId $config.AppId `
                    -Organization $config.Organization `
                    -CertificateThumbprint $config.CertificateThumbprint `
                    -ShowBanner:$false
            }
        }
        else {
            Write-Host -ForegroundColor Yellow -BackgroundColor Black "Purview session authorization needed. Expect a prompt."
            if ($EnableSearchOnlySession) {
                Write-Verbose "EnableSearchOnlySession specified"
                Connect-IPPSSession -ShowBanner:$false -EnableSearchOnlySession
            }
            else {
                Connect-IPPSSession -ShowBanner:$false
            }
        }

        try {
            Write-Verbose "Checking for required Purview permissions..."
            Get-ComplianceSearch -ResultSize 1 -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Verbose "Insufficient permissions for Purview Search"
            throw "Purview permission validation failed: $($_.Exception.Message)"
        }
    }
    Write-Verbose "Connected to IPPS Session successfully"
    # endregion
}