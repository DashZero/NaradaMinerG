﻿using module ..\Include.psm1

$Path = ".\Bin\AMD-KL-556\sgminer.exe"
$Uri = "https://github.com/KL0nLutiy/sgminer-gm-x16r/releases/download/5.5.6-kl/sgminer-5.5.6-kl-windows.zip"

$Commands = [PSCustomObject]@{
    "x16r" = " --intensity 18" #Raven increase 19,21
    "x16s" = "" #x16s
    "xevan" = "" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--api-listen -k $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week * 0.99}
        API = "Xgminer"
        Port = 4028
        URI = $Uri
    }
}