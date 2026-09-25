# Optional Windows DNS helper. Run on a DNS management host with authorized credentials.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ZoneName,
    [Parameter(Mandatory)][string]$SscRecordName,
    [Parameter(Mandatory)][string]$SaltRecordName,
    [Parameter(Mandatory)][System.Net.IPAddress]$ContourAddress,
    [Parameter(Mandatory)][System.Net.IPAddress]$SaltAddress,
    [string]$DnsServer = 'localhost'
)
$ErrorActionPreference = 'Stop'
if ($ContourAddress.AddressFamily -ne 'InterNetwork' -or $SaltAddress.AddressFamily -ne 'InterNetwork') {
    throw 'This helper creates IPv4 A records only.'
}
if ($SscRecordName -eq $SaltRecordName) { throw 'SSC and Salt must use distinct record names.' }
$Records = @{}
$Records[$SscRecordName] = $ContourAddress.IPAddressToString
$Records[$SaltRecordName] = $SaltAddress.IPAddressToString
Get-DnsServerZone -ComputerName $DnsServer -Name $ZoneName | Out-Null
# Inspect all conflicts before making any changes.
$Missing = @()
foreach ($Name in $Records.Keys) {
    $Existing = @(Get-DnsServerResourceRecord -ComputerName $DnsServer -ZoneName $ZoneName -ErrorAction Stop |
        Where-Object { $_.HostName -eq $Name })
    if ($Existing.Count -eq 0) { $Missing += $Name; continue }
    $Conflicting = @($Existing | Where-Object {
        $_.RecordType -ne 'A' -or $_.RecordData.IPv4Address.IPAddressToString -ne $Records[$Name]
    })
    if ($Conflicting.Count -gt 0) { throw "Conflicting DNS record for $Name.$ZoneName; no changes made." }
}
foreach ($Name in $Missing) {
    Add-DnsServerResourceRecordA -ComputerName $DnsServer -ZoneName $ZoneName -Name $Name `
        -IPv4Address $Records[$Name] -TimeToLive ([TimeSpan]::FromMinutes(5))
}
foreach ($Name in $Records.Keys) {
    Resolve-DnsName "$Name.$ZoneName" -Server $DnsServer -Type A
}
