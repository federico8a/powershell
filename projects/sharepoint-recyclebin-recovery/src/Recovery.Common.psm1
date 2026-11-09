Set-StrictMode -Version Latest

function ConvertTo-RecoveryTarget {
    param([Parameter(Mandatory)][string]$Url, [ValidateSet('Auto','Exact','Prefix')][string]$MatchMode = 'Auto')
    $uri = $null
    if (-not [uri]::TryCreate($Url.Trim(), [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
        throw 'Enter an absolute HTTPS SharePoint Online URL.'
    }
    if ($uri.Host -notmatch '(?i)\.sharepoint\.(com|de|cn)$') {
        throw 'Only Microsoft-hosted SharePoint Online domains (*.sharepoint.com/.de/.cn) are supported.'
    }
    $segments = @($uri.AbsolutePath.Trim('/').Split('/', [System.StringSplitOptions]::RemoveEmptyEntries))
    $collectionPath = ''
    if ($segments.Count -ge 2 -and $segments[0] -in @('sites','teams','personal')) {
        $collectionPath = '/' + $segments[0] + '/' + $segments[1]
    }
    $scopePath = [uri]::UnescapeDataString($uri.AbsolutePath).TrimEnd('/')
    # SharePoint's AllItems.aspx library/folder view may have an 'id' query pointing at the actual folder.
    if ($uri.AbsolutePath -match '(?i)/Forms/[^/]+\.aspx$') {
        $idParam = ($uri.Query.TrimStart('?').Split('&') | Where-Object { $_ -match '^(?i)id=' } | Select-Object -First 1)
        if (-not $idParam) { throw 'A library Forms view needs an id= folder path. Supply the library/folder URL directly instead.' }
        $scopePath = [uri]::UnescapeDataString($idParam.Substring(3)).TrimEnd('/')
    }
    if ([string]::IsNullOrEmpty($scopePath)) { $scopePath = '/' }
    if (-not $scopePath.StartsWith('/')) { throw 'The selected scope must be a server-relative path.' }
    if ($scopePath.Split('/') -contains '..' -or $scopePath.Split('/') -contains '.') { throw 'Dot segments are not allowed in recovery scope.' }
    $collectionPathRaw = $collectionPath
    $collectionPath = [uri]::UnescapeDataString($collectionPath)
    $isWithinCollection = ($collectionPath -eq '' -or $scopePath.Equals($collectionPath, [StringComparison]::OrdinalIgnoreCase) -or $scopePath.StartsWith("$collectionPath/", [StringComparison]::OrdinalIgnoreCase))
    if (-not $isWithinCollection) { throw 'The supplied scope is outside its inferred site collection.' }
    if ($MatchMode -eq 'Auto') {
        $leaf = $scopePath.Split('/')[-1]
        $MatchMode = if ($leaf -match '\.[^.]+$') { 'Exact' } else { 'Prefix' }
    }
    [pscustomobject]@{ SiteUrl = "$($uri.Scheme)://$($uri.Host)$collectionPathRaw"; ScopePath = $scopePath; MatchMode = $MatchMode }
}

function Resolve-RecoveryItemPath {
    param([string]$DirName, [string]$LeafName, [string]$CollectionPath)
    if ([string]::IsNullOrWhiteSpace($DirName) -or [string]::IsNullOrWhiteSpace($LeafName)) { throw 'Missing original directory or filename.' }
    $root = $CollectionPath.TrimEnd('/')
    $dir = [uri]::UnescapeDataString($DirName.Replace('\','/')).TrimEnd('/')
    if (-not $dir.StartsWith('/')) {
        $candidate = '/' + $dir.TrimStart('/')
        if ($root -and ($candidate.Equals($root,[StringComparison]::OrdinalIgnoreCase) -or $candidate.StartsWith("$root/",[StringComparison]::OrdinalIgnoreCase))) {
            $dir = $candidate
        } else {
            $dir = "$root/$($dir.TrimStart('/'))"
        }
    }
    if (-not $dir) { $dir = '/' }
    if ($dir.Split('/') -contains '..' -or $dir.Split('/') -contains '.') { throw 'Dot segments are not allowed in original item paths.' }
    if ($LeafName -match '[/\\]' -or $LeafName -in @('.','..')) { throw 'Invalid recycle-bin item name.' }
    $itemPath = ($dir.TrimEnd('/') + '/' + $LeafName).Replace('//','/')
    if ($root -and -not ($itemPath.StartsWith("$root/",[StringComparison]::OrdinalIgnoreCase))) {
        throw "Item path outside target collection: $itemPath"
    }
    return $itemPath
}

function Test-RecoveryScope {
    param([string]$ItemPath,[string]$ScopePath,[ValidateSet('Exact','Prefix')][string]$MatchMode)
    if ($MatchMode -eq 'Exact') { return $ItemPath.Equals($ScopePath,[StringComparison]::OrdinalIgnoreCase) }
    return ($ScopePath -eq '/' -or $ItemPath.StartsWith("$($ScopePath.TrimEnd('/'))/",[StringComparison]::OrdinalIgnoreCase) -or $ItemPath.Equals($ScopePath,[StringComparison]::OrdinalIgnoreCase))
}

function Test-RecoveryDeleter {
    param([object]$Item,[string]$DeletedBy)
    if (-not $DeletedBy) { return $true }
    $needle = $DeletedBy.Trim()
    if ($needle.Contains('@')) { return ([string]$Item.DeletedByEmail).Equals($needle,[StringComparison]::OrdinalIgnoreCase) }
    $emailLocal = ([string]$Item.DeletedByEmail).Split('@')[0]
    return (([string]$Item.DeletedByName).Equals($needle,[StringComparison]::OrdinalIgnoreCase) -or $emailLocal.Equals($needle,[StringComparison]::OrdinalIgnoreCase))
}

function Get-RecoveryInventory {
    param([object[]]$RecycleItems,[string]$CollectionPath,[string]$ScopePath,[string]$MatchMode,[string]$DeletedBy,[Nullable[datetime]]$DeletedFromUtc,[Nullable[datetime]]$DeletedBeforeUtc)
    $output = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $RecycleItems) {
        $kind = [string]$item.ItemType
        # PnP CSOM may represent the enum as a string or its numeric value.
        if ($kind -in @('1','File')) { $kind = 'File' }
        elseif ($kind -in @('5','Folder')) { $kind = 'Folder' }
        else { continue }
        $rawDeleted = [datetime]$item.DeletedDate
        # SharePoint CSOM normally supplies UTC; unspecified Kind is interpreted as UTC rather than workstation local.
        $deletedAt = if ($rawDeleted.Kind -eq [DateTimeKind]::Unspecified) { [datetime]::SpecifyKind($rawDeleted,[DateTimeKind]::Utc) } else { $rawDeleted.ToUniversalTime() }
        if ($null -ne $DeletedFromUtc -and $deletedAt -lt $DeletedFromUtc) { continue }
        if ($null -ne $DeletedBeforeUtc -and $deletedAt -ge $DeletedBeforeUtc) { continue }
        if (-not (Test-RecoveryDeleter -Item $item -DeletedBy $DeletedBy)) { continue }
        $path = Resolve-RecoveryItemPath -DirName ([string]$item.DirName) -LeafName ([string]$item.LeafName) -CollectionPath $CollectionPath
        if (-not (Test-RecoveryScope -ItemPath $path -ScopePath $ScopePath -MatchMode $MatchMode)) { continue }
        $output.Add([pscustomobject]@{ Id = [string]$item.Id; Type = $kind; Stage = [string]$item.ItemState;
            Path = $path; DeletedUtc = $deletedAt.ToString('o'); DeletedByEmail = [string]$item.DeletedByEmail;
            DeletedByName = [string]$item.DeletedByName; SizeBytes = [long]$item.Size })
    }
    return @($output | Sort-Object -Property Id -Unique)
}

function Export-RecoveryJsonAtomic {
    param([object]$Data,[string]$Path)
    $folder = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force) }
    $tmp = "$Path.tmp"
    ConvertTo-Json -InputObject $Data -Depth 12 | Set-Content -LiteralPath $tmp -Encoding utf8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Export-RecoveryCsvSafe {
    param([object[]]$Rows,[string]$Path)
    # Export a viewing copy only. The authoritative manifest is JSON; mitigate CSV formula injection.
    $safe = @(foreach ($row in $Rows) {
        if ($null -eq $row) { continue }
        $obj = [ordered]@{}
        foreach ($p in $row.PSObject.Properties) {
            $v = $p.Value
            if ($v -is [string] -and $v -match '^[\s]*[=+@\-\t\r]') { $v = "'" + $v }
            $obj[$p.Name] = $v
        }
        [pscustomobject]$obj
    })
    if ($safe.Count -gt 0) {
        $safe | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding utf8
    } else {
        # A zero-match run should still create its CSV inventory artifact.
        Set-Content -LiteralPath $Path -Value '"NoMatchingEntries"' -Encoding utf8
    }
}

Export-ModuleMember -Function ConvertTo-RecoveryTarget,Resolve-RecoveryItemPath,Test-RecoveryScope,Test-RecoveryDeleter,Get-RecoveryInventory,Export-RecoveryJsonAtomic,Export-RecoveryCsvSafe

function Get-RecoveryRetryAdvice {
    <#
      Pure interpretation of an exception's HTTP response. It does not sleep or retry.
      Retry-After is a lower bound, even if it exceeds the default exponential cap.
    #>
    param([Parameter(Mandatory)][System.Exception]$Exception)
    $status = 0
    $retryAfter = 0
    $current = $Exception
    while ($null -ne $current) {
        $response = $null
        if ($current.PSObject.Properties.Name -contains 'Response') { $response = $current.Response }
        if ($null -ne $response) {
            try { $status = [int]$response.StatusCode } catch { }
            $value = $null
            try { $value = $response.Headers.RetryAfter.Delta.TotalSeconds } catch { }
            if ($null -ne $value) {
                $retryAfter = [math]::Max($retryAfter, [math]::Ceiling([double]$value))
            } else {
                try { $value = $response.Headers['Retry-After'] } catch { }
                if ($null -ne $value) {
                    $seconds = 0
                    $asString = [string]$value
                    if ([int]::TryParse($asString, [ref]$seconds)) {
                        $retryAfter = [math]::Max($retryAfter, $seconds)
                    } else {
                        $date = [datetimeoffset]::MinValue
                        if ([datetimeoffset]::TryParse($asString, [ref]$date)) {
                            $retryAfter = [math]::Max($retryAfter, [math]::Ceiling(($date - [datetimeoffset]::UtcNow).TotalSeconds))
                        }
                    }
                }
            }
        }
        $current = $current.InnerException
    }
    $throttled = $status -in @(429,503)
    if (-not $throttled -and $status -eq 0) {
        # Last resort for some wrapped PnP exceptions that discard the HTTP response.
        $throttled = $Exception.ToString() -match '(?i)(\b429\b|\b503\b|throttl|too many requests|server too busy)'
    }
    [pscustomobject]@{ Throttled = [bool]$throttled; RetryAfterSeconds = [int][math]::Max(0,$retryAfter); StatusCode = $status }
}

function Test-RecoveryManifest {
    param([Parameter(Mandatory)]$Manifest)
    if ($Manifest.Schema -ne 1) { throw 'Unsupported or missing manifest schema.' }
    if ([string]$Manifest.ScopePath -match '(^|/)(\.\.?)(/|$)') { throw 'Manifest scope contains dot segments.' }
    $target = ConvertTo-RecoveryTarget -Url ([string]$Manifest.SiteUrl) -MatchMode Prefix
    if ($target.SiteUrl -cne [string]$Manifest.SiteUrl) { throw 'Manifest site must be a canonical site collection URL.' }
    if ([string]$Manifest.MatchMode -cnotin @('Exact','Prefix')) { throw 'Invalid manifest match mode.' }
    if (-not (Test-RecoveryScope -ItemPath ([string]$Manifest.ScopePath) -ScopePath $target.ScopePath -MatchMode Prefix)) {
        throw 'Manifest scope is outside the target site collection.'
    }
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($Manifest.Items)) {
        $parsed = [guid]::Empty
        if (-not [guid]::TryParse([string]$item.Id,[ref]$parsed) -or $parsed -eq [guid]::Empty) { throw 'Invalid or missing item ID in manifest.' }
        if (-not $seen.Add([string]$item.Id)) { throw 'Duplicate item ID in manifest.' }
        if ($item.Type -cnotin @('File','Folder')) { throw 'Unknown item type in manifest.' }
        if ([string]$item.Path -match '(^|/)(\.\.?)(/|$)') { throw 'Manifest item path contains dot segments.' }
        if (-not (Test-RecoveryScope -ItemPath ([string]$item.Path) -ScopePath ([string]$Manifest.ScopePath) -MatchMode ([string]$Manifest.MatchMode))) {
            throw 'Manifest item path is outside selected recovery scope.'
        }
    }
    return $true
}

Export-ModuleMember -Function Get-RecoveryRetryAdvice,Test-RecoveryManifest

function Test-RecoveryLiveItem {
    # Match saved data against a freshly enumerated recycle-bin record, not just its GUID.
    # The ID must not be used to restore something moved outside the approved scope.
    param([Parameter(Mandatory)]$Saved, [Parameter(Mandatory)]$Live)
    return (([string]$Saved.Id).Equals([string]$Live.Id,[StringComparison]::OrdinalIgnoreCase) -and
            ([string]$Saved.Path).Equals([string]$Live.Path,[StringComparison]::OrdinalIgnoreCase) -and
            ([string]$Saved.Type).Equals([string]$Live.Type,[StringComparison]::OrdinalIgnoreCase) -and
            ([string]$Saved.DeletedUtc).Equals([string]$Live.DeletedUtc,[StringComparison]::OrdinalIgnoreCase) -and
            ([string]$Saved.DeletedByEmail).Equals([string]$Live.DeletedByEmail,[StringComparison]::OrdinalIgnoreCase))
}
Export-ModuleMember -Function Test-RecoveryLiveItem
