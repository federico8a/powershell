#Requires -Version 7.2
<#
.SYNOPSIS
  Preflight, initiate Microsoft Purview PST export (Graph v1.0), or hash downloaded PSTs.
.NOTES
  Starts an eDiscovery export of the ENTIRE configured search; it does not download a PST.
  Create/estimate the appropriately scoped Purview case/search in the GUI first.
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidateSet('Preflight','Export','Verify')][string]$Action,
 [string]$Mailbox,[string]$AdminUPN,[guid]$CaseId,[guid]$SearchId,
 [string]$PstFolder,[string]$ManifestPath,
 [switch]$ConfirmSearchScope,[switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
switch($Action) {
 'Preflight' {
  if(-not $Mailbox){throw 'Specify -Mailbox.'}
  Import-Module ExchangeOnlineManagement -ErrorAction Stop
  $connection=@{ShowBanner=$false}
  if($AdminUPN){$connection.UserPrincipalName=$AdminUPN}
  Connect-ExchangeOnline @connection | Out-Null
  try {
   $m=Get-Mailbox -Identity $Mailbox -ErrorAction Stop
   $s=Get-MailboxStatistics -Identity $Mailbox -ErrorAction Stop
   [pscustomobject]@{Address=$m.PrimarySmtpAddress;Guid=$m.ExchangeGuid;Type=$m.RecipientTypeDetails;Archive=$m.ArchiveStatus;Hold=$m.LitigationHoldEnabled;Count=$s.ItemCount;Size=$s.TotalItemSize.ToString()}
  } finally {Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null}
 }
 'Export' {
  if(-not $Mailbox -or $CaseId -eq [guid]::Empty -or $SearchId -eq [guid]::Empty){throw 'Specify -Mailbox -CaseId -SearchId.'}
  Write-Warning 'The entire pre-existing search is exported, NOT necessarily -Mailbox. Confirm search sources, filters, archive, legal permission, partially indexed items, licenses and E3 API PAYG billing.'
  if(-not($Execute -and $ConfirmSearchScope)){Write-Host 'DRY RUN: No export. Add -ConfirmSearchScope -Execute after approval.';return}
  Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
  Connect-MgGraph -Scopes 'eDiscovery.ReadWrite.All' -NoWelcome -ErrorAction Stop | Out-Null
  try {
   $url="https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases/$CaseId/searches/$SearchId/exportResult"
   $data=@{displayName=('AuthorizedPST-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'));exportCriteria='searchHits';exportFormat='pst';additionalOptions='splitSource,includeFolderAndPath,condensePaths,includeReport'}|ConvertTo-Json
   $null=Invoke-MgGraphRequest -Method POST -Uri $url -Body $data -ContentType 'application/json' -Headers @{Prefer='include-unknown-enum-members'} -StatusCodeVariable 'httpStatus' -ResponseHeadersVariable 'httpHeaders' -ErrorAction Stop
   if([int]$httpStatus -ne 202){throw "Unexpected status $httpStatus"}
   Write-Host 'Export accepted (HTTP 202). Go to Purview eDiscovery case > Processes / Export packages; download and inspect within 14 days.'
   [pscustomobject]@{HttpStatus=$httpStatus;CaseId=$CaseId;SearchId=$SearchId;Location=$httpHeaders['Location']}
  } finally {Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null}
 }
 'Verify' {
  if(-not $PstFolder -or -not $ManifestPath){throw 'Specify -PstFolder -ManifestPath.'}
  if(-not(Test-Path -LiteralPath $PstFolder -PathType Container)){throw 'PST folder not found.'}
  $files=@(Get-ChildItem -LiteralPath $PstFolder -Filter '*.pst' -File -Recurse)
  if(-not $files.Count){throw 'No PST files found.'}
  $root=[IO.Path]::GetFullPath($PstFolder)
  $manifest=[pscustomobject]@{CreatedUtc=[DateTime]::UtcNow.ToString('o');Limitation='SHA-256 proves file integrity, NOT completeness';Files=@($files|ForEach-Object{[pscustomobject]@{RelativePath=[IO.Path]::GetRelativePath($root,$_.FullName);Bytes=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})}
  $manifest|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ManifestPath -Encoding utf8NoBOM
  $manifest
 }
}
