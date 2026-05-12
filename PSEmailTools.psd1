@{
    RootModule        = 'PurviewEmailTools.psm1'
    ModuleVersion     = '1.0.0'
    PowerShellVersion = '7.0'

    RequiredModules = @(
        @{
            ModuleName = 'ExchangeOnlineManagement'
            ModuleVersion = '3.0.0'
        }
    )

    FunctionsToExport = @(
        'New-PurviewEmailSearch'
        'Invoke-PurviewEmailSearch'
        'Invoke-PurviewEmailPurge'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags = @(
                'Purview'
                'eDiscovery'
                'Compliance'
                'ExchangeOnline'
            )

            ProjectUri = 'https://github.com/M-Clowes/PSEmailTools'
        }
    }
}
