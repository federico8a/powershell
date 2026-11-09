# Executed once per worker-bucket in its own PowerShell 7 runspace. Never log tokens.
param(
    [Parameter(Mandatory)][object[]]$Items,
    [Parameter(Mandatory)][string]$SiteUrl,
    [Parameter(Mandatory)][string]$SharePointToken,
    [ValidateSet('Skip','AllowRename')][string]$CollisionPolicy = 'Skip',
    [ValidateRange(0,12)][int]$MaxRetries = 6
)
$ErrorActionPreference = 'Stop'
Import-Module PnP.PowerShell -ErrorAction Stop

Import-Module (Join-Path $PSScriptRoot 'Recovery.Common.psm1') -ErrorAction Stop

function Test-TargetOccupied {
    param([string]$Path,[string]$Type,[object]$Connection)
    # Explicit null distinguishes a missing file from authentication/permission/network failure.
    if ($Type -eq 'File') { return ($null -ne (Get-PnPFile -Url $Path -AsListItem -Connection $Connection -ErrorAction Stop)) }
    try { return ($null -ne (Get-PnPFolder -Url $Path -Connection $Connection -ErrorAction Stop)) }
    catch {
        if ($_.Exception.Message -match '(?i)(404|not found|does not exist|file not found)') { return $false }
        throw
    }
}

function Invoke-SingleRestore {
    param([object]$Item,[object]$Connection,[string]$CollisionPolicy,[int]$MaxRetries)
    $attempt = 0
    $totalThrottleRetries = 0
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        try {
            if ($CollisionPolicy -eq 'Skip') {
                if (Test-TargetOccupied -Path $Item.Path -Type $Item.Type -Connection $Connection) {
                    return [pscustomobject]@{ Id = $Item.Id; Type = $Item.Type; Path = $Item.Path; Status = 'SkippedExistingPath'; Retries = $totalThrottleRetries; Seconds = [math]::Round($clock.Elapsed.TotalSeconds,2); Error = '' }
                }
            }
            # GUID identity is stable; no fragile positional or name matching.
            Restore-PnPRecycleBinItem -Identity ([guid]$Item.Id) -Force -Connection $Connection -ErrorAction Stop
            return [pscustomobject]@{ Id = $Item.Id; Type = $Item.Type; Path = $Item.Path; Status = 'RestoreCommandSucceeded'; Retries = $totalThrottleRetries; Seconds = [math]::Round($clock.Elapsed.TotalSeconds,2); Error = '' }
        }
        catch {
            $throttle = Get-RecoveryRetryAdvice -Exception $_.Exception
            if ($throttle.Throttled -and $attempt -lt $MaxRetries) {
                $attempt++
                $totalThrottleRetries++
                $backoff = [int][math]::Min(300,[math]::Pow(2,$attempt) + (Get-Random -Minimum 0 -Maximum 5))
                Start-Sleep -Seconds ([math]::Max($backoff,$throttle.RetryAfterSeconds))
                continue
            }
            # A timeout or 'item no longer found' is ambiguous: mark for verification rather than blindly retrying.
            $category = if ($throttle.Throttled) { 'ThrottledExhausted' } else { 'NeedsManualReview' }
            return [pscustomobject]@{ Id = $Item.Id; Type = $Item.Type; Path = $Item.Path; Status = $category; Retries = $totalThrottleRetries; Seconds = [math]::Round($clock.Elapsed.TotalSeconds,2); Error = ([string]$_.Exception.Message).Substring(0,[math]::Min(600,([string]$_.Exception.Message).Length)) }
        }
    }
}

try {
    $connection = Connect-PnPOnline -Url $SiteUrl -AccessToken $SharePointToken -ReturnConnection -ErrorAction Stop
} catch {
    foreach ($item in $Items) {
        [pscustomobject]@{ Id = $item.Id; Type = $item.Type; Path = $item.Path; Status = 'ConnectionFailed'; Retries = 0; Seconds = 0; Error = ([string]$_.Exception.Message) }
    }
    return
}
foreach ($item in $Items) {
    Invoke-SingleRestore -Item $item -Connection $connection -CollisionPolicy $CollisionPolicy -MaxRetries $MaxRetries
}
