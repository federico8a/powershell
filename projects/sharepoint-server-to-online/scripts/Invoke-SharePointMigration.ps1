# Windows PowerShell + installed SPMT module. Default Plan mode is offline.
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$TargetHost,
    [ValidateSet('Plan','Scan','Migrate')][string]$Mode='Plan',
    [string]$UserMappingPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ($TargetHost -notmatch '^[a-zA-Z0-9-]+\.sharepoint\.(com|us|cn)$') {
    throw 'Supply an exact approved SharePoint tenant host. Other clouds require reviewed adaptation.'
}
$rows=@(Import-Csv -LiteralPath $ManifestPath)
if ($rows.Count -eq 0) { throw 'Manifest is empty.' }
$seenSource=@{}; $seenTarget=@{}
foreach ($r in $rows) {
    if (-not $r.PSObject.Properties['SourceSiteUrl'] -or -not $r.PSObject.Properties['TargetSiteUrl']) {
        throw 'Required columns: SourceSiteUrl,TargetSiteUrl'
    }
    $s=$null; $t=$null
    if (-not [uri]::TryCreate($r.SourceSiteUrl,[UriKind]::Absolute,[ref]$s) -or
        -not [uri]::TryCreate($r.TargetSiteUrl,[UriKind]::Absolute,[ref]$t)) { throw 'Invalid URL.' }
    if ($s.Scheme -notin @('http','https') -or $t.Scheme -ne 'https' -or
        $t.Host -ine $TargetHost -or -not $t.IsDefaultPort -or
        $s.UserInfo -or $t.UserInfo -or $s.Query -or $t.Query -or $s.Fragment -or $t.Fragment) {
        throw 'URLs must be sites, without credentials/query/fragment; target must match approved host.'
    }
    $sk=$s.AbsoluteUri.TrimEnd('/'); $tk=$t.AbsoluteUri.TrimEnd('/')
    if ($seenSource.ContainsKey($sk) -or $seenTarget.ContainsKey($tk)) { throw 'Duplicate source or target.' }
    $seenSource[$sk]=$true; $seenTarget[$tk]=$true
}
$rows | Format-Table SourceSiteUrl,TargetSiteUrl
if ($Mode -eq 'Plan') { Write-Output 'Plan only. No Microsoft connection or writes.'; return }
if (-not $UserMappingPath -or -not (Test-Path -LiteralPath $UserMappingPath -PathType Leaf)) {
    throw 'Supply an SPMT-format identity mapping file validated during the pilot.'
}
if (-not $PSCmdlet.ShouldProcess($TargetHost,"$Mode $($rows.Count) approved site tasks")) { return }
Import-Module Microsoft.SharePoint.MigrationTool.PowerShell -ErrorAction Stop
Write-Warning 'Use a fresh SPMT PowerShell process. Preserve prior task reports before starting.'
$sourceCredential=Get-Credential -Message 'Authorized SharePoint on-premises source account'
if ($null -eq $sourceCredential) { throw 'Source credentials cancelled.' }
# No embedded target password: installed SPMT handles its supported interactive sign-in.
# Scan mode cannot automatically promote itself to a migration.
Register-SPMTMigration -ScanOnly ($Mode -eq 'Scan') `
    -StartMigrationAutomaticallyWhenNoScanIssue $false `
    -AutomaticUserMapping $false -UserMappingFile (Resolve-Path -LiteralPath $UserMappingPath).Path `
    -PreserveUserPermissionsForSharePointSource $true -PreservePermissionInheritance $true `
    -MigrateFileVersionHistory $true -KeepAllVersions $true
foreach ($r in $rows) {
    Add-SPMTTask -SharePointSourceCredential $sourceCredential `
        -SharePointSourceSiteUrl $r.SourceSiteUrl -TargetSiteUrl $r.TargetSiteUrl -MigrateAll
}
Start-SPMTMigration
Get-SPMTMigration
# A returned session object is not business acceptance. Inspect reports and all task outcomes.
