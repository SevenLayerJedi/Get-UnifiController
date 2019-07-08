param 
( 
  [string]$IPAddress, 
  [string]$CIDR,
  [string]$Port
) 


############################################
# .variables                               #
############################################


$userName = "ubnt"
$password = "ubnt"
$commandToRun = "set-transform http://10.10.10.10:8080/inform"


############################################
# .functions                               #
############################################


function Check-PortUp([string]$IPAddress, [string]$Port) {
  $socket = New-Object System.Net.Sockets.TCPClient
  $connected = ($socket.BeginConnect( $IPAddress, $Port, $Null, $Null )).AsyncWaitHandle.WaitOne(300)
  if ($connected -eq "True"){
    return $TRUE
  }else{
    return $FALSE
  } 
}


function Grab-Banner([string]$IPAddress, [string]$Port) {
  $socket = New-Object System.Net.Sockets.TCPClient
  $connected = ($socket.BeginConnect( $IPAddress, $Port, $Null, $Null )).AsyncWaitHandle.WaitOne(300)
  if ($connected -eq "True"){
    $stream = $socket.getStream()
    Start-Sleep -m 500; $text = ""
    $text = "    [+] BANNER: "
    
    while ($stream.DataAvailable){
      $text += [char]$stream.ReadByte()
    }
    
    $socket.Close()
    return $text
  }else{
    Write-Host " [-] PORT NOT OPEN: $($IPAddress)" -foregroundcolor red
  } 
}


# Taken from https://gallery.technet.microsoft.com/scriptcenter/List-the-IP-addresses-in-a-60c5bb6b
function Get-IPrange
{
<# 
  .SYNOPSIS  
    Get the IP addresses in a range 
  .EXAMPLE 
   Get-IPrange -start 192.168.8.2 -end 192.168.8.20 
  .EXAMPLE 
   Get-IPrange -ip 192.168.8.2 -mask 255.255.255.0 
  .EXAMPLE 
   Get-IPrange -ip 192.168.8.3 -cidr 24 
#> 
 
param 
( 
  [string]$start, 
  [string]$end, 
  [string]$ip, 
  [string]$mask, 
  [int]$cidr 
) 
 
  function IP-toINT64 (){ 
    param ($ip) 
   
    $octets = $ip.split(".") 
    return [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3]) 
  } 
   
  function INT64-toIP(){ 
    param ([int64]$int) 

    return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() )
  } 
   
  if ($ip) {$ipaddr = [Net.IPAddress]::Parse($ip)} 
  if ($cidr) {$maskaddr = [Net.IPAddress]::Parse((INT64-toIP -int ([convert]::ToInt64(("1"*$cidr+"0"*(32-$cidr)),2)))) } 
  if ($mask) {$maskaddr = [Net.IPAddress]::Parse($mask)} 
  if ($ip) {$networkaddr = new-object net.ipaddress ($maskaddr.address -band $ipaddr.address)} 
  if ($ip) {$broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address))} 
   
  if ($ip){ 
    $startaddr = IP-toINT64 -ip $networkaddr.ipaddresstostring 
    $endaddr = IP-toINT64 -ip $broadcastaddr.ipaddresstostring 
  }else{ 
    $startaddr = IP-toINT64 -ip $start 
    $endaddr = IP-toINT64 -ip $end 
  } 
   
  for ($i = $startaddr; $i -le $endaddr; $i++){ 
    INT64-toIP -int $i 
  }

}


############################################
# .main                                    #
############################################


# Get rid of all the errors but save the initial state
$beforeSErrorPref = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

# Get all the ip's
$ipsToScan = Get-IPrange -ip $($IPAddress) -cidr $($CIDR)

# Blank list to hold found IP's
# $ipObj = @()

# Loop through and see which ones have port 22 open
foreach ($ip in $ipsToScan){
  if ($(Check-PortUp -IPAddress $($ip) -Port $($Port))){
    Write-host " [+] IP: $($ip)" -foregroundcolor green
    Write-host "   [+] OPEN PORT $($Port)" -foregroundcolor cyan
    $banner = Grab-Banner -IPAddress $($ip) -Port $($Port)
    Write-host "$($banner)" -foregroundcolor cyan
    # $ipObj += $ip
    if ($banner -Like "*dropbear*"){
      Write-Host "   [+] ******************* FOUND UBIQUITI SWITCH: $($ip) *******************"
      # Command to accept new KEY
      # Invoke-Expression "echo y | plink -ssh -l $userName -pw $($password) $($ip) exit"
      
      # Command to set-inform
      # Invoke-Expression "plink -ssh -l $userName -pw $($password) $($ip) $($commandToRun)"
      
    }
  }else{
    Write-host " [-] NO ONE HOME: $($ip)"  -foregroundcolor red
  }
}

# Set the error pref back to what it was before
$ErrorActionPreference = $beforeSErrorPref


