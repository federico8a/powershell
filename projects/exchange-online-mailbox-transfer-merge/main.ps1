#Requires -Version 7.2
<# Microsoft Exchange Online same-tenant mailbox access / merge. NO LIVE-TENANT TESTS. #>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidateSet('Inspect','Delegate','ConvertShared','MergeDeleted','MergeStatus','GenerateImportMap')][string]$Action,
 [string]$SourceMailbox,[string]$TargetMailbox,[guid]$SourceExchangeGuid,[string]$AdminUPN,
 [switch]$GrantSendAs,[switch]$Execute,
 [string]$PstPath,[string]$CsvPath,[string]$TargetFolder='/ImportedFromOldUser',
 [string]$RequestIdentity
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Action -eq 'GenerateImportMap'){
 if(-not $PstPath -or -not $CsvPath -or -not $TargetMailbox){throw 'Require -PstPath -CsvPath -TargetMailbox'}
 $pst=Get-Item -LiteralPath $PstPath -ErrorAction Stop
 if($pst.Extension -ine '.pst'){throw 'Expected .pst file'}
 if($pst.Length -gt 20GB){Write-Warning 'Microsoft recommends PST <=20GB for network import.'}
 if($TargetMailbox -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$'){throw 'Invalid target email'}
 if($TargetFolder -notmatch '^/[A-Za-z0-9_.-]+$'){throw 'Use simple /TargetFolder'}
 [pscustomobject][ordered]@{
  Workload='Exchange';FilePath='';Name=$pst.Name;Mailbox=$TargetMailbox;IsArchive='FALSE'
  TargetRootFolder=$TargetFolder;ContentCodePage='';SPFileContainer='';SPManifestContainer='';SPSiteUrl=''
 } | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding utf8NoBOM
 Write-Host "Mapping created: $CsvPath. Upload PST using supported AzCopy in Purview then submit mapping CSV. This command does not import."
 return
}
Import-Module ExchangeOnlineManagement -ErrorAction Stop
$connection=@{ShowBanner=$false}
if($AdminUPN){$connection.UserPrincipalName=$AdminUPN}
Connect-ExchangeOnline @connection | Out-Null
try {
 switch($Action) {
  'Inspect' {
   if(-not $SourceMailbox -or -not $TargetMailbox){throw 'Specify -SourceMailbox -TargetMailbox'}
   $a=Get-Mailbox -Identity $SourceMailbox -ErrorAction Stop
   $b=Get-Mailbox -Identity $TargetMailbox -ErrorAction Stop
   if($a.ExchangeGuid -eq $b.ExchangeGuid){throw 'Source and target are identical'}
   foreach($m in @($a,$b)){
    $s=Get-MailboxStatistics -Identity $m.PrimarySmtpAddress.ToString()
    [pscustomobject]@{Mailbox=$m.PrimarySmtpAddress;Type=$m.RecipientTypeDetails;Guid=$m.ExchangeGuid;Archive=$m.ArchiveStatus;Hold=$m.LitigationHoldEnabled;Items=$s.ItemCount;Size=$s.TotalItemSize.ToString()}
   }
  }
  'Delegate' {
   if(-not $SourceMailbox -or -not $TargetMailbox){throw 'Specify -SourceMailbox -TargetMailbox'}
   $a=Get-Mailbox -Identity $SourceMailbox -ErrorAction Stop
   $b=Get-Mailbox -Identity $TargetMailbox -ErrorAction Stop
   if($a.ExchangeGuid -eq $b.ExchangeGuid){throw 'Same mailbox'}
   Write-Host "Granting FullAccess on $($a.PrimarySmtpAddress) to $($b.PrimarySmtpAddress), SendAs=$($GrantSendAs.IsPresent)"
   if(-not $Execute){Write-Warning 'DRY RUN: add -Execute';break}
   Add-MailboxPermission -Identity $a.PrimarySmtpAddress.ToString() -User $b.PrimarySmtpAddress.ToString() -AccessRights FullAccess -InheritanceType All -AutoMapping $false -ErrorAction Stop | Out-Null
   if($GrantSendAs){Add-RecipientPermission -Identity $a.PrimarySmtpAddress.ToString() -Trustee $b.PrimarySmtpAddress.ToString() -AccessRights SendAs -Confirm:$false -ErrorAction Stop | Out-Null}
   Get-MailboxPermission -Identity $a.PrimarySmtpAddress.ToString() -User $b.PrimarySmtpAddress.ToString() | Select-Object Identity,User,AccessRights
  }
  'ConvertShared' {
   if(-not $SourceMailbox){throw 'Specify -SourceMailbox'}
   $a=Get-Mailbox -Identity $SourceMailbox -ErrorAction Stop
   if($a.RecipientTypeDetails -eq 'SharedMailbox'){Write-Host 'Already shared';break}
   if($a.RecipientTypeDetails -ne 'UserMailbox'){throw 'Only a user mailbox may be converted here'}
   Write-Warning 'Shared mailbox >50GB or with archive/hold requires qualifying license; preserve backing Entra account and block its sign-in separately.'
   if(-not $Execute){Write-Warning 'DRY RUN: add -Execute';break}
   Set-Mailbox -Identity $a.PrimarySmtpAddress.ToString() -Type Shared -ErrorAction Stop
   Get-Mailbox -Identity $a.PrimarySmtpAddress.ToString() | Select-Object PrimarySmtpAddress,RecipientTypeDetails
  }
  'MergeDeleted' {
   if($SourceExchangeGuid -eq [guid]::Empty -or -not $TargetMailbox){throw 'Specify -SourceExchangeGuid and -TargetMailbox'}
   if($TargetFolder -notmatch '^/[A-Za-z0-9_.-]+$'){throw 'Use simple /TargetFolder'}
   $target=Get-Mailbox -Identity $TargetMailbox -ErrorAction Stop
   $sources=@(Get-Mailbox -SoftDeletedMailbox -ResultSize Unlimited -ErrorAction Stop)
   $sources+=@(Get-Mailbox -InactiveMailboxOnly -ResultSize Unlimited -ErrorAction Stop)
   $found=@($sources|Where-Object{$_.ExchangeGuid -eq $SourceExchangeGuid})
   if(-not $found.Count){throw 'Recoverable source GUID NOT FOUND. Never delete a live source to make this work.'}
   if($target.ExchangeGuid -eq $SourceExchangeGuid){throw 'Cannot merge mailbox into itself'}
   Write-Host "Source (recoverable): $($found[0].DisplayName), target: $($target.PrimarySmtpAddress); destination: $TargetFolder"
   Write-Warning 'This is a non-atomic COPY, not transfer of identity. Quota, duplicates, holds and archive require review.'
   if(-not $Execute){Write-Warning 'DRY RUN: add -Execute';break}
   $name='Merge-'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
   New-MailboxRestoreRequest -SourceMailbox $SourceExchangeGuid.ToString() -TargetMailbox $target.ExchangeGuid.ToString() -AllowLegacyDNMismatch -TargetRootFolder ($TargetFolder.TrimStart('/')) -Name $name -ErrorAction Stop |
    Select-Object Identity,Name,Status,TargetMailbox
  }
  'MergeStatus' {
   if(-not $RequestIdentity){throw 'Specify -RequestIdentity'}
   Get-MailboxRestoreRequest -Identity $RequestIdentity | Get-MailboxRestoreRequestStatistics | Format-List Status,PercentComplete,ItemsTransferred,ItemsSkipped,Message
  }
 }
} finally {Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null}
