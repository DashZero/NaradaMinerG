﻿using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$ZergPoolCoins_Request = [PSCustomObject]@{}

try {
    $ZergPoolCoins_Request = Invoke-RestMethod "http://api.zergpool.com:8080/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($ZergPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

try {
    $ZergpoolCoins_Variance = Invoke-RestMethod "https://semitest.000webhostapp.com/variance/zergpoolc.variance.txt" -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
}
catch {
    Write-Log -Level Warn "Pool Variance ($Name) has failed. "
    return
}

$ZergPoolCoins_Regions = "us", "europe"
$ZergPoolCoins_Currencies = @("BTC", "LTC") + ($ZergPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$ZergPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$ExcludeCoin -inotcontains $ZergPoolCoins_Request.$_.name -and $ExcludeAlgorithm -inotcontains (Get-Algorithm $ZergPoolCoins_Request.$_.algo) -and ($Coin.count -eq 0 -or $Coin -icontains $ZergPoolCoins_Request.$_.name) -and $ZergPoolCoins_Request.$_.hashrate -gt 0 -and $ZergPoolCoins_Request.$_.noautotrade -eq 0} | ForEach-Object {
    $ZergPoolCoins_Host = "mine.zergpool.com"
    $ZergPoolCoins_Port = $ZergPoolCoins_Request.$_.port
    $ZergPoolCoins_Algorithm = $ZergPoolCoins_Request.$_.algo
    $ZergPoolCoins_Algorithm_Norm = Get-Algorithm $ZergPoolCoins_Algorithm
    $ZergPoolCoins_Coin = $ZergPoolCoins_Request.$_.name
	$ZergpoolCoins_Fee = $ZergpoolCoins_Variance.$_.fees
    $ZergPoolCoins_Currency = $_

    $Divisor = 1000000000

    switch ($ZergPoolCoins_Algorithm_Norm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "keccak" {$Divisor *= 1000}
        "sha256t"{$Divisor *= 1000}
        "keccakc"{$Divisor *= 1000}
        "yescrypt"{$Divisor /= 1000}
        "yescryptr16"{$Divisor /= 1000}
    }
	
	$ZergpoolCoins_Fees = 1-($ZergpoolCoins_Fee/100)
	
    $Variance = 1
	
    $Variance = 1 - $ZergpoolCoins_Variance."$ZergPoolCoins_Currency".variance
	
    if($CREA -and $ZergPoolCoins_Currency -eq "CREA"){$Variance = 1}
    if($YTN -and $ZergPoolCoins_Currency -eq "YTN"){$Variance = 1}
    if($PGN -and $ZergPoolCoins_Currency -eq "PGN"){$Variance = 1}
    if($RVN -and $ZergPoolCoins_Currency -eq "RVN"){$Variance = 1}
    if($HSR -and $ZergPoolCoins_Currency -eq "HSR"){$Variance = 1}
    if($BTX -and $ZergPoolCoins_Currency -eq "BTX"){$Variance = 1}
    if($MAC -and $ZergPoolCoins_Currency -eq "MAC"){$Variance = 1}
	
    $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$ZergPoolCoins_Request.$_.estimate / $Divisor * $ZergpoolCoins_Fees * $Variance) -Duration $StatSpan -ChangeDetection $true

    $ZergPoolCoins_Regions | ForEach-Object {
        $ZergPoolCoins_Region = $_
        $ZergPoolCoins_Region_Norm = Get-Region $ZergPoolCoins_Region

		$ZergPoolCoins_Currencies | ForEach-Object {
        [PSCustomObject]@{
                Algorithm     = $ZergPoolCoins_Algorithm_Norm
                Info          = $ZergPoolCoins_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$ZergPoolCoins_Algorithm.$ZergPoolCoins_Host"
                Port          = $ZergPoolCoins_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_,mc=$ZergPoolCoins_Currency"
                Region        = $ZergPoolCoins_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
				Fees          = $ZergpoolCoins_Fee
				Variance      = $Variance
            }
        }
    }
}
