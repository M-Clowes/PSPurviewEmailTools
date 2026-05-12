function ConvertTo-KqlSafeString {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $san = $Value -replace '\s+', ' '
    $san = $san -replace '"', '""'
    $san = $san -replace '[():]', ' '

    return $san.Trim()
}