Get-ChildItem -Path "contracts\*.clar" | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $clean = New-Object System.Collections.Generic.List[byte]
    foreach ($b in $bytes) {
        if ($b -ne 13) {
            $clean.Add($b)
        }
    }
    [System.IO.File]::WriteAllBytes($_.FullName, $clean.ToArray())
    Write-Host "Fixed: $($_.Name)"
}
