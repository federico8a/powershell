#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Manifest,[Parameter(Mandatory)][string]$Wave,[switch]$Apply)
$ErrorActionPreference='Stop'
$rows=@(Import-Csv $Manifest | Where-Object Wave -eq $Wave)
if (!$rows) { throw "Wave not found: $Wave" }
if (@($rows|Where-Object TargetUrl -match 'contoso').Count) { throw 'Placeholder Contoso target blocked' }
if (!$Apply) {
 Write-Host "DRY RUN wave $Wave. No site created."
 $rows | Select-Object TargetUrl,OwnerUPN,Title,ProvisionMode,StorageQuotaMB | Format-Table
 Write-Host 'ClassicApproved -> STS#0 with explicit approval; Manual -> create approved modern site yourself.'
 return
}
if ((Read-Host "Type PROVISION $Wave to confirm") -cne "PROVISION $Wave") { throw 'Not authorized' }
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
$hostName=([uri]$rows[0].TargetUrl).Host
if ($hostName -notmatch '^([a-z0-9-]+)\.sharepoint\.com$') { throw 'Commercial SPO host required' }
$tenant=$Matches[1]
foreach($r in $rows) {
 if (([uri]$r.TargetUrl).Host -ne $hostName) { throw 'Multiple tenants in one wave forbidden' }
 if ($r.TargetUrl -notmatch '^https://[a-z0-9-]+\.sharepoint\.com/(sites|teams)/[^/?#]+/?$') { throw 'Unsupported target URL' }
}
$adminUrl='https://'+$tenant+'-admin.sharepoint.com'
Connect-SPOService -Url $adminUrl -ErrorAction Stop
$existing=@(Get-SPOSite -Limit All | Select-Object -ExpandProperty Url)
foreach($r in $rows) {
 if ($r.ProvisionMode -eq 'Manual') { Write-Host "MANUAL site provisioning / verification required: $($r.TargetUrl)"; continue }
 if ($r.ProvisionMode -ne 'ClassicApproved') { throw "Bad ProvisionMode: $($r.ProvisionMode)" }
 if ($existing -contains $r.TargetUrl) { Write-Host "EXISTS, unchanged: $($r.TargetUrl)"; continue }
 $quota=[long]$r.StorageQuotaMB
 if ($quota -lt 1024) { throw 'Quota must be at least 1024 MB' }
 New-SPOSite -Url $r.TargetUrl -Owner $r.OwnerUPN -StorageQuota $quota -Title $r.Title -Template 'STS#0' -ErrorAction Stop
 Write-Host "CREATED (classic STS#0): $($r.TargetUrl)"
}
Write-Warning 'Validate template, quota, security/retention and custom features before importing content.'
