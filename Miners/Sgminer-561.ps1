﻿using module ..\Include.psm1

$Path = ".\Bin\AMD-NiceHash-561\sgminer.exe"
$Uri = "https://github.com/nicehash/sgminer/releases/download/5.6.1/sgminer-5.6.1-nicehash-51-windows-amd64.zip"

$Commands = [PSCustomObject]@{
    #"bitcore" = "" #Bitcore
    #"blake2s" = "" #Blake2s
    #"c11" = "" #C11
    #"equihash" = " --gpu-threads 2 --worksize 256" #Equihash
    #"ethash" = " --gpu-threads 1 --worksize 192 --xintensity 1024" #Ethash
    "groestlcoin" = " --gpu-threads 2 --worksize 128 --intensity d" #Groestl
    #"hmq1725" = "" #HMQ1725
    #"jha" = "" #JHA
    "maxcoin" = "" #Keccak
    "lyra2rev2" = " --gpu-threads 2 --worksize 128 --intensity d" #Lyra2RE2
    #"lyra2z" = " --worksize 32 --intensity 18" #Lyra2z
    #"neoscrypt" = " --gpu-threads 1 --worksize 64 --intensity 15" #NeoScrypt
    #"skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"x11evo" = "" #X11evo
    #"x17" = "" #X17
    "yescrypt" = " --worksize 4 --rawintensity 256" #Yescrypt
    #"xevan-mod" = " --intensity 15" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--api-listen -k $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Xgminer"
        Port = 4028
        URI = $Uri
    }
}