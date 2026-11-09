#requires -Version 7.4
<#
.SYNOPSIS
Inventories and restores deleted SharePoint Online files/folders, using up to 10 workers.
.DESCRIPTION
Safe by default: produces an inventory only unless -Apply is explicitly supplied.
On -Apply, requires a typed confirmation before any restoration. Supports resume from a manifest directory.
.EXAMPLE
./Invoke-SharePointRecovery.ps1 -ClientId <GUID>
.EXAMPLE
./Invoke-SharePointRecovery.ps1 -ClientId <GUID> -TargetUrl https://contoso.sharepoint.com/sites/Finance/Shared%20Documents -DeletedBy user@contoso.com -DeletedFrom 2026-10-20 -DeletedBefore 2026-10-21
.EXAMPLE
./Invoke-SharePointRecovery.ps1 -ClientId <GUID> -ResumePath ./reports/20261029_120000 -Apply
#>
[CmdletBinding()]
param(
    [string]$TargetUrl,
    [Parameter(Mandatory)][guid]$ClientId,
    [string]$DeletedBy,
    [string]$DeletedFrom,
    [string]$DeletedBefore,
    [ValidateSet('Auto','Exact','Prefix')][string]$MatchMode = 'Auto',
    [switch]$Apply,
    [string]$ResumePath,
    [string]$ReportRoot = (Join-Path $PSScriptRoot 'reports'),
    [ValidateRange(1,10)][int]$Workers = 10,
    [ValidateRange(10,5000)][int]$BatchSize = 200,
    [ValidateRange(100,1000000)][int]$RowLimit = 100000,
    [ValidateRange(0,12)][int]$MaxRetries = 6,
    [ValidateSet('Skip','AllowRename')][string]$CollisionPolicy = 'Skip'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'src/Recovery.Common.psm1') -Force
Import-Module PnP.PowerShell -ErrorAction Stop
if ([version]$PSVersionTable.PSVersion -lt [version]'7.4') { throw 'PowerShell 7.4 or newer required.' }

function Invoke-RecoveryReadWithRetry {
    param([scriptblock]$Operation, [int]$MaxRetries)
    for ($attempt = 0; ; $attempt++) {
        try { return @(& $Operation) }
        catch {
            $advice = Get-RecoveryRetryAdvice -Exception $_.Exception
            if (-not $advice.Throttled -or $attempt -ge $MaxRetries) { throw }
            $delay = [int][math]::Max($advice.RetryAfterSeconds,[math]::Min(300,[math]::Pow(2,$attempt+1) + (Get-Random -Minimum 0 -Maximum 5)))
            Write-Warning "SharePoint throttled read (attempt $($attempt+1)); waiting $delay seconds."
            Start-Sleep -Seconds $delay
        }
    }
}

function Read-RecycleBinSnapshot {
    param([object]$Connection,[int]$RowLimit,[int]$MaxRetries)
    $first = @(Invoke-RecoveryReadWithRetry -MaxRetries $MaxRetries -Operation { Get-PnPRecycleBinItem -FirstStage -RowLimit $RowLimit -Connection $Connection -ErrorAction Stop })
    $second = @(Invoke-RecoveryReadWithRetry -MaxRetries $MaxRetries -Operation { Get-PnPRecycleBinItem -SecondStage -RowLimit $RowLimit -Connection $Connection -ErrorAction Stop })
    if ($first.Count -ge $RowLimit -or $second.Count -ge $RowLimit) {
        throw "Recycle bin enumeration reached RowLimit=$RowLimit. Inventory could be truncated; increase -RowLimit and repeat. Nothing was restored."
    }
    return @($first) + @($second)
}

function Save-Results {
    param([object[]]$Results,[string]$Directory)
    $lastById = @($Results | Group-Object -Property Id | ForEach-Object { $_.Group[-1] })
    Export-RecoveryJsonAtomic -Data $lastById -Path (Join-Path $Directory 'results.json')
    Export-RecoveryCsvSafe -Rows $lastById -Path (Join-Path $Directory 'results.csv')
}

if ($ResumePath) {
    $runDir = (Resolve-Path -LiteralPath $ResumePath).Path
    $manifest = Get-Content -LiteralPath (Join-Path $runDir 'manifest.json') -Raw | ConvertFrom-Json
    [void](Test-RecoveryManifest -Manifest $manifest)
    $target = [pscustomobject]@{ SiteUrl = $manifest.SiteUrl; ScopePath = $manifest.ScopePath; MatchMode = $manifest.MatchMode }
    $items = @($manifest.Items)
    $previous = if (Test-Path -LiteralPath (Join-Path $runDir 'results.json')) { @(Get-Content -LiteralPath (Join-Path $runDir 'results.json') -Raw | ConvertFrom-Json) } else { @() }
    if ($TargetUrl) {
        $requested = ConvertTo-RecoveryTarget -Url $TargetUrl -MatchMode $MatchMode
        if ($requested.SiteUrl -ne $target.SiteUrl -or $requested.ScopePath -ne $target.ScopePath) {
            throw 'TargetUrl does not match the saved manifest scope.'
        }
    }
    if ($DeletedBy -or $DeletedFrom -or $DeletedBefore) { throw 'Filters cannot be changed when resuming a saved manifest. Create a new inventory.' }
    Write-Host "Loaded saved inventory: $($items.Count) entries."
} else {
    if (-not $TargetUrl) { $TargetUrl = Read-Host 'Paste a site, subsite, library, folder or file SharePoint URL' }
    $target = ConvertTo-RecoveryTarget -Url $TargetUrl -MatchMode $MatchMode
    if (-not $DeletedFrom) { $DeletedFrom = Read-Host 'Deleted from UTC (YYYY-MM-DD, blank for any)' }
    if (-not $DeletedBefore) { $DeletedBefore = Read-Host 'Deleted before UTC, exclusive (YYYY-MM-DD, blank for any)' }
    if (-not $DeletedBy) { $DeletedBy = Read-Host 'Deleted by exact email or username (blank for any)' }
    $fromUtc = $null
    $beforeUtc = $null
    if ($DeletedFrom) { $fromUtc = [datetime]::SpecifyKind([datetime]::ParseExact($DeletedFrom,'yyyy-MM-dd',[cultureinfo]::InvariantCulture),[DateTimeKind]::Utc) }
    if ($DeletedBefore) { $beforeUtc = [datetime]::SpecifyKind([datetime]::ParseExact($DeletedBefore,'yyyy-MM-dd',[cultureinfo]::InvariantCulture),[DateTimeKind]::Utc) }
    if ($fromUtc -and $beforeUtc -and $fromUtc -ge $beforeUtc) { throw '-DeletedBefore must be after -DeletedFrom.' }
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff')
    $runDir = Join-Path $ReportRoot $stamp
    [void](New-Item -ItemType Directory -Path $runDir -ErrorAction Stop)
    $previous = @()
}

Write-Host "Connecting to $($target.SiteUrl) with delegated authentication..."
$connection = Connect-PnPOnline -Url $target.SiteUrl -ClientId $ClientId -Interactive -ReturnConnection -ErrorAction Stop
# Requires site collection admin; fail closed on missing scope/read rights.
[void](Get-PnPWeb -Connection $connection -ErrorAction Stop)
if (-not $ResumePath) {
    Write-Host 'Enumerating BOTH recycle bin stages. Large site collections may take some time...'
    $snapshot = @(Read-RecycleBinSnapshot -Connection $connection -RowLimit $RowLimit -MaxRetries $MaxRetries)
    $collectionPath = [uri]::UnescapeDataString(([uri]$target.SiteUrl).AbsolutePath.TrimEnd('/'))
    $items = @(Get-RecoveryInventory -RecycleItems $snapshot -CollectionPath $collectionPath -ScopePath $target.ScopePath -MatchMode $target.MatchMode -DeletedBy $DeletedBy -DeletedFromUtc $fromUtc -DeletedBeforeUtc $beforeUtc)
    $manifest = [pscustomobject]@{ Schema = 1; SiteUrl = $target.SiteUrl; ScopePath = $target.ScopePath; MatchMode = $target.MatchMode;
        DeletedFromUtc = $DeletedFrom; DeletedBeforeUtc = $DeletedBefore; DeletedBy = $DeletedBy; CreatedUtc = (Get-Date).ToUniversalTime().ToString('o'); Items = @($items) }
    Export-RecoveryJsonAtomic -Data $manifest -Path (Join-Path $runDir 'manifest.json')
    Export-RecoveryCsvSafe -Rows $items -Path (Join-Path $runDir 'inventory.csv')
    $daily = @(foreach ($g in ($items | Group-Object -Property { '{0}|{1}|{2}|{3}' -f $_.DeletedUtc.Substring(0,10),$_.DeletedByEmail,$_.Type,$_.Stage })) {
        $firstItem = $g.Group[0]
        [pscustomobject]@{ DeletedDateUtc=$firstItem.DeletedUtc.Substring(0,10); DeletedByEmail=$firstItem.DeletedByEmail; Type=$firstItem.Type; Stage=$firstItem.Stage; Entries=$g.Count; DirectSizeBytes=($g.Group | Measure-Object -Property SizeBytes -Sum).Sum }
    })
    Export-RecoveryCsvSafe -Rows $daily -Path (Join-Path $runDir 'summary-by-date-user.csv')
}
$files = @($items | Where-Object Type -eq 'File')
$folders = @($items | Where-Object Type -eq 'Folder')
$bytes = ($files | Measure-Object -Property SizeBytes -Sum).Sum
if (-not $bytes) { $bytes = 0 }
Write-Host "`nScope: $($target.ScopePath) [$($target.MatchMode)]"
Write-Host "Selected: $($items.Count) entries = $($files.Count) direct files + $($folders.Count) folders; direct-file sizes: $([math]::Round($bytes / 1GB, 3)) GiB"
Write-Warning 'Deleted folder entries may contain files not individually present in the recycle bin. Direct-file counts are not a complete recursive count.'
Write-Host "Reports: $runDir"
if (-not $Apply) { Write-Host 'DRY RUN COMPLETE. To restore, re-run with -ResumePath <report directory> -Apply -ClientId <GUID>.'; return }
if ($items.Count -eq 0) { Write-Warning 'No items matched. Nothing to restore.'; return }

$pending = @($items | Where-Object { $_.Id -notin @($previous | Where-Object Status -eq 'RestoreCommandSucceeded' | ForEach-Object Id) })
Write-Host "Previously succeeded: $($items.Count-$pending.Count); still to evaluate: $($pending.Count)"
$expected = "RESTORE $($pending.Count)"
$typed = Read-Host "Type exactly '$expected' to proceed; any other input cancels"
if ($typed -cne $expected) { Write-Warning 'Canceled. Inventory retained; nothing restored by this invocation.'; return }

# On resume, and after restoring folders, rescan to avoid replaying IDs already restored by someone else.
Write-Host 'Checking current recycle bin IDs before applying changes...'
$present = @(Read-RecycleBinSnapshot -Connection $connection -RowLimit $RowLimit -MaxRetries $MaxRetries)
$availableIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($x in $present) { [void]$availableIds.Add([string]$x.Id) }
$collectionPath = [uri]::UnescapeDataString(([uri]$target.SiteUrl).AbsolutePath.TrimEnd('/'))
$liveInventory = @(Get-RecoveryInventory -RecycleItems $present -CollectionPath $collectionPath -ScopePath $target.ScopePath -MatchMode $target.MatchMode)
$liveById = @{}
foreach ($li in $liveInventory) { $liveById[$li.Id] = $li }
$results = [System.Collections.Generic.List[object]]::new()
foreach ($result in $previous) { $results.Add($result) }
foreach ($successful in @($previous | Where-Object { $_.Status -eq 'RestoreCommandSucceeded' -and $availableIds.Contains([string]$_.Id) })) {
    $results.Add([pscustomobject]@{ Id=$successful.Id; Type=$successful.Type; Path=$successful.Path; Status='ReportedSuccessStillInBinManualReview'; Retries=0; Seconds=0; Error='Prior run reported success, but ID still exists in recycle bin. Verify before retrying.' })
}
foreach ($missing in @($pending | Where-Object { -not $availableIds.Contains($_.Id) })) {
    $results.Add([pscustomobject]@{ Id=$missing.Id; Type=$missing.Type; Path=$missing.Path; Status='AbsentVerifyDestination'; Retries=0; Seconds=0; Error='No longer in the recycle bin at execution time; verify manually.' })
}
$verifiedPending = [System.Collections.Generic.List[object]]::new()
foreach ($candidate in $pending) {
    if (-not $availableIds.Contains($candidate.Id)) { continue }
    if (-not $liveById.ContainsKey($candidate.Id) -or -not (Test-RecoveryLiveItem -Saved $candidate -Live $liveById[$candidate.Id])) {
        $results.Add([pscustomobject]@{ Id=$candidate.Id; Type=$candidate.Type; Path=$candidate.Path; Status='ManifestMismatchManualReview'; Retries=0; Seconds=0; Error='Saved item metadata does not match current live recycle-bin metadata, or the item is outside approved scope.' })
        continue
    }
    $verifiedPending.Add($candidate)
}
$pending = @($verifiedPending.ToArray())
Save-Results -Results @($results.ToArray()) -Directory $runDir
$workerFile = Join-Path $PSScriptRoot 'src/Restore-Worker.ps1'

# Parent folders must finish before nested folders. Recheck the bin between depth levels:
# restoring one folder can implicitly restore a nested folder entry.
$folderPending = @($pending | Where-Object Type -eq 'Folder' | Sort-Object @{ Expression={($_.Path.Split('/').Count)} },Path)
if ($folderPending.Count) {
    Write-Host "Restoring up to $($folderPending.Count) folders sequentially, parent depths first..."
    $levels = @($folderPending | Group-Object -Property { $_.Path.Split('/').Count } | Sort-Object { [int]$_.Name })
    foreach ($level in $levels) {
        # Requery before each depth, fail closed if the snapshot cannot be completed.
        $present = @(Read-RecycleBinSnapshot -Connection $connection -RowLimit $RowLimit -MaxRetries $MaxRetries)
        $availableIds.Clear()
        foreach ($x in $present) { [void]$availableIds.Add([string]$x.Id) }
        $atDepth = @($level.Group)
        foreach ($missing in @($atDepth | Where-Object { -not $availableIds.Contains($_.Id) })) {
            $results.Add([pscustomobject]@{ Id=$missing.Id; Type=$missing.Type; Path=$missing.Path; Status='AbsentVerifyDestination'; Retries=0; Seconds=0; Error='No longer in recycle bin after restoring an ancestor. Verify destination.' })
        }
        $atDepth = @($atDepth | Where-Object { $availableIds.Contains($_.Id) })
        for ($start=0; $start -lt $atDepth.Count; $start += $BatchSize) {
            $slice = @($atDepth | Select-Object -Skip $start -First $BatchSize)
            $token = Get-PnPAccessToken -ResourceTypeName SharePoint -Connection $connection -ErrorAction Stop
            $new = @(& $workerFile -Items $slice -SiteUrl $target.SiteUrl -SharePointToken $token -CollisionPolicy $CollisionPolicy -MaxRetries $MaxRetries)
            foreach ($r in $new) { $results.Add($r) }
            Save-Results -Results @($results.ToArray()) -Directory $runDir
        }
        Save-Results -Results @($results.ToArray()) -Directory $runDir
    }
    Write-Host 'Rechecking recycle bin after parent/folder restoration...'
    $present = @(Read-RecycleBinSnapshot -Connection $connection -RowLimit $RowLimit -MaxRetries $MaxRetries)
    $availableIds.Clear()
    foreach ($x in $present) { [void]$availableIds.Add([string]$x.Id) }
}

$filePending = @($pending | Where-Object Type -eq 'File')
foreach ($missing in @($filePending | Where-Object { -not $availableIds.Contains($_.Id) })) {
    $results.Add([pscustomobject]@{ Id=$missing.Id; Type=$missing.Type; Path=$missing.Path; Status='AbsentVerifyDestination'; Retries=0; Seconds=0; Error='Disappeared from recycle bin after folder restoration; verify.' })
}
$filePending = @($filePending | Where-Object { $availableIds.Contains($_.Id) })
Save-Results -Results @($results.ToArray()) -Directory $runDir
$activeWorkers = $Workers
for ($start=0; $start -lt $filePending.Count; $start += $BatchSize) {
    $slice = @($filePending | Select-Object -Skip $start -First $BatchSize)
    $bucketCount = [math]::Min($activeWorkers,$slice.Count)
    $buckets = @()
    for ($j=0; $j -lt $bucketCount; $j++) {
        $bucketItems = @()
        for ($k=$j; $k -lt $slice.Count; $k += $bucketCount) { $bucketItems += $slice[$k] }
        $buckets += [pscustomobject]@{ Number=$j; Items=$bucketItems }
    }
    $token = Get-PnPAccessToken -ResourceTypeName SharePoint -Connection $connection -ErrorAction Stop
    $siteForWorker = $target.SiteUrl
    $policyForWorker = $CollisionPolicy
    $retryForWorker = $MaxRetries
    Write-Host "Restoring file batch $([math]::Floor($start/$BatchSize)+1): $($slice.Count) files / $bucketCount worker connections..."
    $new = @($buckets | ForEach-Object -Parallel {
        $scriptFile = $using:workerFile
        & $scriptFile -Items $_.Items -SiteUrl $using:siteForWorker -SharePointToken $using:token -CollisionPolicy $using:policyForWorker -MaxRetries $using:retryForWorker
    } -ThrottleLimit $bucketCount)
    foreach ($r in $new) { $results.Add($r) }
    Save-Results -Results @($results.ToArray()) -Directory $runDir
    $throttles = @($new | Where-Object { $_.Retries -gt 0 -or $_.Status -eq 'ThrottledExhausted' }).Count
    if ($throttles -gt 0) { $activeWorkers = [math]::Max(1,[math]::Floor($activeWorkers/2)); Write-Warning "$throttles requests throttled/retried; reducing next batch to $activeWorkers workers." }
    elseif ($activeWorkers -lt $Workers) { $activeWorkers++ }
}
$summary = $results.ToArray() | Group-Object Status | Sort-Object Name | Select-Object Name,Count
$summary | Format-Table -AutoSize
Write-Host "Saved to $runDir. 'RestoreCommandSucceeded' is command acceptance, not independent destination validation."
Write-Warning 'Review NeedsManualReview / AbsentVerifyDestination / SkippedExistingPath, verify destination content and versions, and inspect Microsoft 365 audit logs.'
