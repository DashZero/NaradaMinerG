﻿using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$YiiMPCoins_Request = [PSCustomObject]@{}

try {
    $YiiMPCoins_Request = Invoke-RestMethod "http://api.yiimp.eu/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($YiiMPCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$YiiMP_Regions = "us"
$YiiMP_Currencies = ($YiiMPCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$YiiMP_Currencies | Where-Object {$ExcludeAlgorithm -inotcontains (Get-Algorithm $YiiMPCoins_Request.$_.algo) -and $YiiMPCoins_Request.$_.hashrate -gt 0} | ForEach-Object {
    $YiiMP_Host = "yiimp.eu"
    $YiiMP_Port = $YiiMPCoins_Request.$_.port
    $YiiMP_Algorithm = $YiiMPCoins_Request.$_.algo
    $YiiMP_Algorithm_Norm = Get-Algorithm $YiiMP_Algorithm
    $YiiMP_Coin = $YiiMPCoins_Request.$_.name
    $YiiMP_Currency = $_
    $YiiMP_Fee = $YiiMPCoins_Request.$_.fees

    $Divisor = 1000000000

    switch ($YiiMP_Algorithm_Norm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
    }

    $YiiMP_Fees = 1-($YiiMP_Fee/100)
	
    $Stat = Set-Stat -Name "$($Name)_$($YiiMP_Algorithm_Norm)_Profit" -Value ([Double]$YiiMPCoins_Request.$_.estimate / $Divisor  * $YiiMP_Fees) -Duration $StatSpan -ChangeDetection $true

    $YiiMP_Regions | ForEach-Object {
        $YiiMP_Region = $_
        $YiiMP_Region_Norm = Get-Region $YiiMP_Region

        [PSCustomObject]@{
            Algorithm     = $YiiMP_Algorithm_Norm
            Info          = $YiiMP_Coin
            Price         = $Stat.Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $YiiMP_Host
            Port          = $YiiMP_Port
            User          = Get-Variable $YiiMP_Currency -ValueOnly
            Pass          = "$Worker,c=$YiiMP_Currency"
            Region        = $YiiMP_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
			Fees          = $YiiMP_Fee
        }
    }
}
