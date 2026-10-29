#requires -Version 7.4
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$UserMappingFile,
 [string]$OutputPath=(Join-Path $PSScriptRoot '..\output')
)
$ErrorActionPreference='Stop'
if (!(Test-Path -LiteralPath $UserMappingFile)) { throw 'Supply an approved SPMT mapping CSV with no header.' }
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop
Import-Module Microsoft.Graph.Groups -ErrorAction Stop
# Read-only delegated identity check. Requires tenant approval/consent to requested scopes.
Connect-MgGraph -Scopes @('User.Read.All','Group.Read.All') -ContextScope Process -NoWelcome
$rows=@(Import-Csv -LiteralPath $UserMappingFile -Header SourceLogin,TargetUPN,IsGroup)
$report=New-Object 'System.Collections.Generic.List[object]'
foreach($row in $rows) {
 $state='MISSING';$id='';$licenseCount='';$detail=''
 try {
  if ($row.IsGroup -ieq 'TRUE') {
   # AD/security group mapping is not equivalent to a SharePoint site group.
   $escaped=$row.TargetUPN.Replace("'","''")
   $groups=@(Get-MgGroup -Filter "mail eq '$escaped'" -All -ErrorAction Stop)
   if($groups.Count -eq 1) {$state='FOUND_GROUP_REVIEW_MEMBERSHIP';$id=$groups[0].Id}
   elseif ($groups.Count -gt 1) {$state='AMBIGUOUS_GROUP'}
   else {$state='GROUP_NOT_FOUND_BY_MAIL'}
  } elseif ($row.IsGroup -ieq 'FALSE') {
   $user=Get-MgUser -UserId $row.TargetUPN -Property @('id','userPrincipalName','accountEnabled','assignedLicenses') -ErrorAction Stop
   $id=$user.Id
   $licenseCount=@($user.AssignedLicenses).Count
   if (!$user.AccountEnabled) {$state='DISABLED_USER'}
   elseif ([int]$licenseCount -eq 0) {$state='UNLICENSED_USER'}
   else {$state='USER_FOUND_REVIEW_SPO_ENTITLEMENT'}
  } else { $state='INVALID_ISGROUP_FLAG' }
 } catch { $detail=$_.Exception.Message; $state='REVIEW_GRAPH_ERROR_OR_NOT_FOUND' }
 $report.Add([pscustomobject]@{
  SourceLogin=$row.SourceLogin;TargetUPN=$row.TargetUPN;IsGroup=$row.IsGroup;
  ObjectId=$id;AssignedLicenseCount=$licenseCount;Status=$state;Details=$detail
 })
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$dest=Join-Path $OutputPath 'identity-mapping-validation.csv'
$report | Export-Csv -LiteralPath $dest -Encoding utf8 -NoTypeInformation
Write-Host "Report: $dest"
Write-Warning 'License count does not prove SharePoint Online service-plan entitlement. Review license SKU/servicePlan status, nested groups, orphaned users, SharePoint groups, guest accounts and item permissions separately.'
