Describe 'tooling safeguards' {
    BeforeAll {
        $main = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../Invoke-SharePointRecovery.ps1') -Raw
        $worker = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../src/Restore-Worker.ps1') -Raw
    }
    It 'defaults to inventory-only and requires explicit Apply' {
        $main | Should -Match '\[switch\]\$Apply'
        $main | Should -Match 'if \(-not \$Apply\)'
        $main | Should -Match '\$typed -cne \$expected'
    }
    It 'uses a bounded parallel worker throttle' {
        $main | Should -Match 'ValidateRange\(1,10\)'
        $main | Should -Match 'ForEach-Object -Parallel'
        $main | Should -Match 'ThrottleLimit \$bucketCount'
    }
    It 'uses per-item ID with confirmation suppressed only after approval' {
        $worker | Should -Match 'Restore-PnPRecycleBinItem -Identity'
        $worker | Should -Match '\-Force'
        $worker | Should -Match 'SkippedExistingPath'
    }
}
