#requires -Version 5.1
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$Manifest,
 [Parameter(Mandatory)][string]$Wave,
 [ValidateSet('Scan','Initial','Delta','ResetSession','Status')][string]$Mode='Scan',
 [string]$UserMappingFile
)
$ErrorActionPreference='Stop'
Import-Module Microsoft.SharePoint.MigrationTool.PowerShell -ErrorAction Stop
$rows=@(Import-Csv -LiteralPath $Manifest | Where-Object Wave -eq $Wave)
if (!$rows) { throw "No rows in wave $Wave" }
if (@($rows | Where-Object { $_.SourceUrl -match 'contoso' -or $_.TargetUrl -match 'contoso' }).Count -gt 0) { throw 'Example Contoso mappings cannot be executed.' }
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
# The lock is created from the exact manifest used at the initial/scan operation.
$folder=Join-Path $PSScriptRoot '..\output'
New-Item -Path $folder -ItemType Directory -Force | Out-Null
$lockPath=Join-Path $folder 'spmt-session-lock.json'
$hash=(Get-FileHash -LiteralPath $Manifest -Algorithm SHA256).Hash
$existing=$null
try { $existing=Get-SPMTMigration -ErrorAction Stop } catch { $existing=$null }
if ($Mode -eq 'Status') {
 if (!$existing) { Write-Host 'No SPMT session found for this Windows identity.'; return }
 Write-Host 'SPMT migration session exists. Review status in SPMT UI/Get-SPMTMigration and task logs.'
 if (Test-Path $lockPath) { Get-Content $lockPath }
 return
}
if ($Mode -eq 'ResetSession') {
 if (!$existing) { Write-Host 'No registered SPMT session'; return }
 Write-Warning 'UNREGISTER deletes the local SPMT session and its incremental task state. Never do this in a running session or between initial and delta.'
 if ((Read-Host "Type RESET $Wave after archiving reports") -cne "RESET $Wave") { throw 'Reset rejected' }
 if (!(Test-Path $lockPath)) { throw 'No local session lock: refusing to reset a session this project may not own.' }
 $stored=Get-Content $lockPath -Raw | ConvertFrom-Json
 if ($stored.Wave -ne $Wave) { throw 'Existing lock belongs to another wave.' }
 Unregister-SPMTMigration -ErrorAction Stop
 Remove-Item $lockPath -Force
 Write-Host 'Session unregistered. Historical SPMT reports should be archived separately.'
 return
}
if ($Mode -eq 'Delta') {
 if (!$existing -or !(Test-Path $lockPath)) { throw 'Missing existing migration session. Delta must reuse initial session; do NOT register a fresh migration.' }
 $stored=Get-Content $lockPath -Raw | ConvertFrom-Json
 if ($stored.Wave -ne $Wave -or $stored.Mode -ne 'Initial' -or $stored.ManifestSHA256 -ne $hash) {
  throw 'Wave/session/mapping mismatch. Restore the EXACT initial manifest and active SPMT session. Review the runbook.'
 }
 Write-Warning 'Delta requires independently enforced READ-ONLY source freeze; this script does not freeze SharePoint.'
 if ((Read-Host "Type FROZEN $Wave only after confirming approved change freeze") -cne "FROZEN $Wave") { throw 'Source freeze not confirmed' }
 Start-SPMTMigration -ErrorAction Stop
 Write-Host 'Re-run submitted in same SPMT session. CHECK SPMT detailed logs and Get-SPMTMigration.'
 return
}
if ($existing -or (Test-Path $lockPath)) {
 throw 'An SPMT session or lock already exists. Do NOT use -Force. Review reports, then explicitly run reset-session for this wave BEFORE a fresh scan or initial session.'
}
# One migration session and wave per Windows operator/migration host.
$label = $Mode.ToUpperInvariant()
Write-Host "$label wave $Wave :"
$rows | Select-Object SourceUrl,TargetUrl | Format-Table -AutoSize
# Keep automatic multi-round disabled; reruns are separately operator authorized using Delta mode.
if ($Mode -eq 'Scan') { $confirm="SCAN $Wave" } else { $confirm="MIGRATE $Wave" }
if ((Read-Host "Type $confirm to proceed") -cne $confirm) { throw 'Operator did not authorize.' }
$sourceCredential=Get-Credential -Message 'On-premises SharePoint farm account with access to all source sites in this wave'
# SPMT may prompt for modern SharePoint Online authentication. Validate behavior in your tenant.
$parameters=@{
 ScanOnly=($Mode -eq 'Scan')
 StartMigrationAutomaticallyWhenNoScanIssue=$false
 EnableMultiRound=$false
 MigrateFileVersionHistory=$true
 KeepAllVersions=$true
 MigrateAllSiteFieldsAndContentTypes=$true
 PreserveUserPermissionsForSharePointSource=$true
 PreservePermissionInheritance=$true
 MigrateSiteSettings='PRESERVE_ALL_SETTINGS'
 MigrateNavigation=$true
}
if ($UserMappingFile) {
 if (!(Test-Path -LiteralPath $UserMappingFile)) { throw 'Mapping file not found' }
 $parameters['UserMappingFile']=(Resolve-Path -LiteralPath $UserMappingFile).Path
 $parameters['AutomaticUserMapping']=$false
}
# Intentionally do NOT enable the global term-store import by default (tenant admin and governance review).
# Review -MigrateTermGroups and Power Automate owner settings separately before calling Register-SPMTMigration.
Register-SPMTMigration @parameters -ErrorAction Stop
foreach($row in $rows) {
 Add-SPMTTask -SharePointSourceSiteUrl $row.SourceUrl -SharePointSourceCredential $sourceCredential -TargetSiteUrl $row.TargetUrl -MigrateAll -ErrorAction Stop
}
[pscustomobject]@{Wave=$Wave;Mode=$Mode;ManifestSHA256=$hash;CreatedUtc=(Get-Date).ToUniversalTime().ToString('o')} |
 ConvertTo-Json | Set-Content -LiteralPath $lockPath -Encoding UTF8
Write-Host "Created local session lock: $lockPath"
Start-SPMTMigration -ErrorAction Stop
Write-Warning 'Migration submitted/started; completion and fidelity are NOT verified by this wrapper. Inspect SPMT warnings, task status, reports and business UAT.'
