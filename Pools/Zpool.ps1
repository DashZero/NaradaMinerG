﻿using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Zpool_Request = [PSCustomObject]@{}

try {
    $Zpool_Request = Invoke-RestMethod "http://www.zpool.ca/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $ZpoolCoins_Request = Invoke-RestMethod "http://www.zpool.ca/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Zpool_Regions = "us"
$Zpool_Currencies = @("BTC") + ($ZpoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$ExcludeAlgorithms -inotcontains (Get-Algorithm $Zpool_Request.$_.name) -and $Zpool_Request.$_.hashrate -gt 0}  | ForEach-Object {
    $Zpool_Host = "mine.zpool.ca"
    $Zpool_Port = $Zpool_Request.$_.port
    $Zpool_Algorithm = $Zpool_Request.$_.name
    $Zpool_Algorithm_Norm = Get-Algorithm $Zpool_Algorithm
    $Zpool_Coin = ""

    $Divisor = 1000000

    switch ($Zpool_Algorithm_Norm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "keccak" {$Divisor *= 1000}
        "keccakc" {$Divisor *= 1000}
        "sha256t" {$Divisor *= 1000}
    }	
	
	$Variety = 0
	
    switch ($Zpool_Algorithm_Norm) {
        "blake2s" {$Variety = 0.02}
        "c11" {$Variety = 0.01}
        "equihash" {$Variety = 0.03}
        "hmq1725" {$Variety = 0.11}
        "keccak" {$Variety = 0.02}
        "lyra2v2" {$Variety = 0.02}
        "lyra2z" {$Variety = 0.03}
        "m7m" {$Variety = 0.03}
        "neoscrypt" {$Variety = 0.06}
        "phi" {$Variety = 0.01}
        "sha256t" {$Variety = 0.27} #recheck
        "skunk" {$Variety = 0.04}
        "timetravel" {$Variety = 0.05}
        "tribus" {$Variety = 0.01}
        "x11evo" {$Variety = 0.01}
        "x17" {$Variety = 0.01}
        "xevan" {$Variety = 0.15}
        "yescrypt" {$Variety = 0.24}
    }	

    if ((Get-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_last24h / $Divisor * (1-($Zpool_Request.$_.fees/100)) * (1-$Variety)) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_current / $Divisor * (1-($Zpool_Request.$_.fees/100)) * (1-$Variety)) -Duration $StatSpan -ChangeDetection $true}

    $Zpool_Regions | ForEach-Object {
        $Zpool_Region = $_
        $Zpool_Region_Norm = Get-Region $Zpool_Region

        $Zpool_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $Zpool_Algorithm_Norm
                Info          = $Zpool_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$Zpool_Algorithm.$Zpool_Host"
                Port          = $Zpool_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $Zpool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
