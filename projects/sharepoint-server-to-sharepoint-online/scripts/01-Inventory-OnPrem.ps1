#requires -Version 5.1
[CmdletBinding()]
param([string]$OutputPath=(Join-Path $PSScriptRoot '..\output'))
$ErrorActionPreference='Stop'
# Run on farm as SharePoint farm admin; READ ONLY.
if (!(Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue)) { Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction Stop }
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$sites=New-Object 'System.Collections.Generic.List[object]'
$webs=New-Object 'System.Collections.Generic.List[object]'
$lists=New-Object 'System.Collections.Generic.List[object]'
$features=New-Object 'System.Collections.Generic.List[object]'
$workflows=New-Object 'System.Collections.Generic.List[object]'
foreach($site in (Get-SPSite -Limit All)) {
 try {
  $root=$site.RootWeb
  try {
   $sites.Add([pscustomobject]@{SiteUrl=$site.Url;SiteId=$site.ID;RootTitle=$root.Title;Template="$($root.WebTemplate)#$($root.Configuration)";ContentDatabase=$site.ContentDatabase.Name;SiteOwner=$site.Owner.LoginName})
  } finally { if($root){$root.Dispose()} }
  foreach($f in $site.Features) {
   $features.Add([pscustomobject]@{SiteUrl=$site.Url;Scope='Site';OwnerUrl=$site.Url;FeatureId=$f.DefinitionId;FeatureName=$f.Definition.DisplayName})
  }
  foreach($web in $site.AllWebs) {
   try {
    $relative=$web.Url.Substring($site.Url.TrimEnd('/').Length).TrimStart('/')
    $webs.Add([pscustomobject]@{SiteUrl=$site.Url;WebUrl=$web.Url;WebRelativePath=$relative;Title=$web.Title;Template="$($web.WebTemplate)#$($web.Configuration)";Language=$web.Language;HasUniqueRoleAssignments=$web.HasUniqueRoleAssignments})
    foreach($f in $web.Features) {
     $features.Add([pscustomobject]@{SiteUrl=$site.Url;Scope='Web';OwnerUrl=$web.Url;FeatureId=$f.DefinitionId;FeatureName=$f.Definition.DisplayName})
    }
    foreach($list in $web.Lists) {
     $lists.Add([pscustomobject]@{SiteUrl=$site.Url;WebUrl=$web.Url;WebRelativePath=$relative;ListTitle=$list.Title;ListId=$list.ID;BaseTemplate=$list.BaseTemplate;ItemCount=$list.ItemCount;Hidden=$list.Hidden;EnableVersioning=$list.EnableVersioning;HasUniqueRoleAssignments=$list.HasUniqueRoleAssignments;RelativeUrl=$list.RootFolder.ServerRelativeUrl})
     foreach($wf in $list.WorkflowAssociations) {
      $workflows.Add([pscustomobject]@{SiteUrl=$site.Url;WebUrl=$web.Url;ListTitle=$list.Title;WorkflowName=$wf.Name;WorkflowId=$wf.Id;BaseId=$wf.BaseId})
     }
    }
   } finally { if($web){$web.Dispose()} }
  }
 } finally { if($site){$site.Dispose()} }
}
$sites | Export-Csv (Join-Path $OutputPath 'source-sites.csv') -NoTypeInformation -Encoding UTF8
$webs | Export-Csv (Join-Path $OutputPath 'source-webs.csv') -NoTypeInformation -Encoding UTF8
$lists | Export-Csv (Join-Path $OutputPath 'source-lists.csv') -NoTypeInformation -Encoding UTF8
$features | Export-Csv (Join-Path $OutputPath 'source-features.csv') -NoTypeInformation -Encoding UTF8
$workflows | Export-Csv (Join-Path $OutputPath 'source-workflows.csv') -NoTypeInformation -Encoding UTF8
Get-SPSolution | Select-Object Name,Id,Deployed | Export-Csv (Join-Path $OutputPath 'source-farm-solutions.csv') -NoTypeInformation -Encoding UTF8
Write-Host "Enumerated $($sites.Count) sites, $($webs.Count) webs, $($lists.Count) lists, $($workflows.Count) workflow associations."
Write-Warning 'Contains sensitive tenant inventory. Secure exports; separately assess service apps, InfoPath, branding, farm code, site workflows, item permissions, taxonomy and integrations.'
