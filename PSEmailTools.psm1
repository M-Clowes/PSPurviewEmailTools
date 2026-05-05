Get-ChildItem $PSScriptRoot\Public\*.ps1   | ForEach-Object { . $_ }
Get-ChildItem $PSScriptRoot\Private\*.ps1  | ForEach-Object { . $_ }