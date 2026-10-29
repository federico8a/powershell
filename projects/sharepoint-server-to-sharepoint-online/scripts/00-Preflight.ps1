#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Manifest)
$ErrorActionPreference='Stop'
Write-Host "SharePoint migration preflight - read only" -ForegroundColor Cyan
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'Use Windows PowerShell 5.1 (powershell.exe) for SPMT' }
if (!(Test-Path -LiteralPath $Manifest)) { throw 'Copy config/sites.example.csv to config/sites.csv and edit real site mappings.' }
$rows=@(Import-Csv -LiteralPath $Manifest)
if (!$rows) { throw 'Empty manifest' }
foreach ($p in @('Wave','SourceUrl','TargetUrl','Title','OwnerUPN','ProvisionMode','StorageQuotaMB','Criticality','BusinessOwner')) {
 if (!$rows[0].PSObject.Properties[$p]) { throw "Missing manifest column: $p" }
}
$sourceSeen=@{}; $targetSeen=@{}
foreach($r in $rows) {
 if ($r.Wave -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid wave' }
 foreach ($field in @('SourceUrl','TargetUrl')) {
  $url=$r.$field; $u=$null
  if (!([uri]::TryCreate($url,[UriKind]::Absolute,[ref]$u)) -or $u.UserInfo -or ($field -eq 'TargetUrl' -and $u.Scheme -ne 'https') -or ($field -eq 'SourceUrl' -and $u.Scheme -notin @('http','https'))) { throw "Bad URL: $url" }
  if ($field -eq 'SourceUrl' -and $u.Scheme -eq 'http') { Write-Warning "Unencrypted HTTP on-prem source connection: $url. Requires risk acceptance and secure private network." }
 }
 if ($r.TargetUrl -notmatch '^https://[a-z0-9-]+\.sharepoint\.com/(sites|teams)/[^/?#]+/?$') { throw "Unsupported target URL $($r.TargetUrl)" }
 if ($r.OwnerUPN -notmatch '^[^@\s]+@[^@\s]+$') { throw 'Invalid owner UPN' }
 if ($r.ProvisionMode -notin @('Manual','ClassicApproved')) { throw 'Invalid ProvisionMode' }
 if ($r.StorageQuotaMB -notmatch '^\d+$') { throw 'Invalid StorageQuotaMB' }
 $src=$r.SourceUrl.TrimEnd('/').ToLowerInvariant(); $tgt=$r.TargetUrl.TrimEnd('/').ToLowerInvariant()
 if ($sourceSeen.ContainsKey($src) -or $targetSeen.ContainsKey($tgt)) { throw "Duplicate source or target: $src -> $tgt" }
 $sourceSeen[$src]=1; $targetSeen[$tgt]=1
 if ($src -match 'contoso' -or $tgt -match 'contoso') { Write-Warning 'Demonstration Contoso mapping detected; cannot use for production.' }
}
foreach($module in @('Microsoft.SharePoint.MigrationTool.PowerShell','Microsoft.Online.SharePoint.PowerShell')) {
 if (Get-Module -ListAvailable -Name $module) { Write-Host ('Found: ' + $module) }
 else { Write-Warning ('Install module/tool on corresponding host: ' + $module) }
}
Write-Host "$($rows.Count) mapped site collections. This is a local structural check, not a tenant connectivity, license or farm compatibility check."
