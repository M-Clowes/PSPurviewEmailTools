$public  = Join-Path $PSScriptRoot 'Public'
$private = Join-Path $PSScriptRoot 'Private'

if (Test-Path $private) {
    Get-ChildItem $private\*.ps1 -ErrorAction Stop |
        Sort-Object Name |
        ForEach-Object { . $_ }
}

if (Test-Path $public) {
    Get-ChildItem $public\*.ps1 -ErrorAction Stop |
        Sort-Object Name |
        ForEach-Object { . $_ }
}