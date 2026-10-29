#requires -Version 7.4
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$Manifest,
 [Parameter(Mandatory)][string]$Wave,
 [Parameter(Mandatory)][string]$SourceLists,
 [string]$OutputPath=(Join-Path $PSScriptRoot '..\output')
)
$ErrorActionPreference='Stop'
if (!$env:PNP_CLIENT_ID) { throw 'Set PNP_CLIENT_ID to your approved Entra application client ID (delegated sign-in). Do not embed credentials.' }
Import-Module PnP.PowerShell -ErrorAction Stop
if (!(Test-Path -LiteralPath $SourceLists)) { throw 'Missing source-lists.csv. Run on-prem farm inventory first and copy CSV to secure output folder.' }
$allSource=@(Import-Csv -LiteralPath $SourceLists)
$rows=@(Import-Csv -LiteralPath $Manifest | Where-Object Wave -eq $Wave)
if (!$rows) { throw 'No mapped sites for this wave.' }
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
$results=New-Object 'System.Collections.Generic.List[object]'
$webResults=New-Object 'System.Collections.Generic.List[object]'
foreach($r in $rows) {
 Write-Host "Checking $($r.TargetUrl)" -ForegroundColor Cyan
 # PnP enumerates SUBSITES, then connects to each web to inspect its lists.
 $conn=Connect-PnPOnline -Url $r.TargetUrl -ClientId $env:PNP_CLIENT_ID -Interactive -ReturnConnection -ErrorAction Stop
 $top=Get-PnPWeb -Connection $conn -ErrorAction Stop
 $subs=@(Get-PnPSubWeb -Recurse -Connection $conn -ErrorAction Stop)
 $urls=@($top.Url)+@($subs | Select-Object -ExpandProperty Url)
 foreach($url in $urls) {
  # Reuse PnP token/app identity for child site; PnP might still require a consent/login.
  $child=Connect-PnPOnline -Url $url -ClientId $env:PNP_CLIENT_ID -Interactive -ReturnConnection -ErrorAction Stop
  $relative=$url.TrimEnd('/').Substring($r.TargetUrl.TrimEnd('/').Length).TrimStart('/')
  $webResults.Add([pscustomobject]@{SourceSiteUrl=$r.SourceUrl;TargetSiteUrl=$r.TargetUrl;TargetWebUrl=$url;WebRelativePath=$relative})
  foreach($list in @(Get-PnPList -Connection $child -Includes ItemCount,Hidden,BaseTemplate -ErrorAction Stop)) {
   $src=@($allSource | Where-Object { $_.SiteUrl.TrimEnd('/') -eq $r.SourceUrl.TrimEnd('/') -and $_.WebRelativePath -eq $relative -and $_.ListTitle -eq $list.Title })
   $count=$null; $state='REVIEW_UNMAPPED'
   if ($src.Count -eq 1) {
    $count=[int64]$src[0].ItemCount
    $state=if($count -eq [int64]$list.ItemCount){'COUNT_MATCH_REVIEW'} else {'COUNT_MISMATCH'}
   } elseif ($src.Count -gt 1) { $state='AMBIGUOUS_SOURCE' }
   $results.Add([pscustomobject]@{
    Wave=$Wave;SourceSiteUrl=$r.SourceUrl;TargetSiteUrl=$r.TargetUrl;TargetWebUrl=$url;
    WebRelativePath=$relative;ListTitle=$list.Title;SourceCount=$count;TargetCount=$list.ItemCount;
    Hidden=$list.Hidden;Status=$state
   })
  }
 }
}
$listReport=Join-Path $OutputPath ('target-lists-' + $Wave + '.csv')
$webReport=Join-Path $OutputPath ('target-webs-' + $Wave + '.csv')
$results | Export-Csv -Path $listReport -Encoding utf8 -NoTypeInformation
$webResults | Export-Csv -Path $webReport -Encoding utf8 -NoTypeInformation
# Explicitly report source rows which are entirely missing from destination.
$missing=New-Object 'System.Collections.Generic.List[object]'
foreach($r in $rows) {
 foreach($s in @($allSource|Where-Object { $_.SiteUrl.TrimEnd('/') -eq $r.SourceUrl.TrimEnd('/') })) {
  if (!@($results|Where-Object { $_.SourceSiteUrl -eq $r.SourceUrl -and $_.WebRelativePath -eq $s.WebRelativePath -and $_.ListTitle -eq $s.ListTitle }).Count) {
   $missing.Add([pscustomobject]@{Wave=$Wave;SourceSiteUrl=$r.SourceUrl;WebRelativePath=$s.WebRelativePath;ListTitle=$s.ListTitle;SourceCount=$s.ItemCount;Status='MISSING_TARGET_LIST'})
  }
 }
}
$missing | Export-Csv -Path (Join-Path $OutputPath ('missing-target-lists-' + $Wave + '.csv')) -Encoding utf8 -NoTypeInformation
Write-Host "Enumerated $($webResults.Count) target webs and $($results.Count) target lists; $($missing.Count) missing source lists." -ForegroundColor Yellow
Write-Warning 'Counts are only a preliminary signal. System/hidden items, versions, source-time drift, permissions, data bytes and content parity require separate verification and business sign-off.'
