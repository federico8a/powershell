BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/Recovery.Common.psm1') -Force
}
Describe 'URL parsing' {
    It 'infers site collection and scopes a document library' {
        $t = ConvertTo-RecoveryTarget -Url 'https://contoso.sharepoint.com/sites/Finance/Shared%20Documents'
        $t.SiteUrl | Should -Be 'https://contoso.sharepoint.com/sites/Finance'
        $t.ScopePath | Should -Be '/sites/Finance/Shared Documents'
        $t.MatchMode | Should -Be 'Prefix'
    }
    It 'recognizes an exact file' {
        (ConvertTo-RecoveryTarget -Url 'https://contoso.sharepoint.com/sites/A/Docs/a.docx').MatchMode | Should -Be 'Exact'
    }
    It 'rejects non-SharePoint host' {
        { ConvertTo-RecoveryTarget -Url 'https://evil.example/sites/A' } | Should -Throw
    }
    It 'honors a view id query parameter' {
        $t = ConvertTo-RecoveryTarget -Url 'https://contoso.sharepoint.com/sites/A/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2FA%2FShared%20Documents%2F2026'
        $t.ScopePath | Should -Be '/sites/A/Shared Documents/2026'
    }
}
Describe 'filter and boundaries' {
    It 'does not accidentally include sibling prefix folder' {
        Test-RecoveryScope -ItemPath '/sites/A/FinanceArchive/x.docx' -ScopePath '/sites/A/Finance' -MatchMode Prefix | Should -BeFalse
        Test-RecoveryScope -ItemPath '/sites/A/Finance/x.docx' -ScopePath '/sites/A/Finance' -MatchMode Prefix | Should -BeTrue
    }
    It 'matches email without case sensitivity' {
        Test-RecoveryDeleter -Item ([pscustomobject]@{ DeletedByEmail='Person@Contoso.com'; DeletedByName='Someone' }) -DeletedBy 'person@contoso.com' | Should -BeTrue
    }
    It 'filters date window UTC and enumerates only files and folders' {
        $raw = @(
            [pscustomobject]@{ Id=[guid]::NewGuid();ItemType='File';DirName='/sites/A/Docs';LeafName='a.xlsx';DeletedDate=[datetime]'2026-10-20T15:00:00Z';DeletedByEmail='a@x.test';DeletedByName='A';Size=100;ItemState='FirstStageRecycleBin' },
            [pscustomobject]@{ Id=[guid]::NewGuid();ItemType='Folder';DirName='/sites/A/Docs';LeafName='B';DeletedDate=[datetime]'2026-10-20T10:00:00Z';DeletedByEmail='a@x.test';DeletedByName='A';Size=0;ItemState='SecondStageRecycleBin' },
            [pscustomobject]@{ Id=[guid]::NewGuid();ItemType='File';DirName='/sites/A/Docs';LeafName='excluded.csv';DeletedDate=[datetime]'2026-10-21T00:00:00Z';DeletedByEmail='a@x.test';DeletedByName='A';Size=200;ItemState='FirstStageRecycleBin' },
            [pscustomobject]@{ Id=[guid]::NewGuid();ItemType='List';DirName='/sites/A';LeafName='list';DeletedDate=[datetime]'2026-10-20T10:00:00Z';DeletedByEmail='a@x.test';DeletedByName='A';Size=0;ItemState='FirstStageRecycleBin' }
        )
        $filtered = @(Get-RecoveryInventory -RecycleItems $raw -CollectionPath '/sites/A' -ScopePath '/sites/A/Docs' -MatchMode Prefix -DeletedBy 'a@x.test' -DeletedFromUtc ([datetime]'2026-10-20T00:00:00Z') -DeletedBeforeUtc ([datetime]'2026-10-21T00:00:00Z'))
        $filtered.Count | Should -Be 2
        @($filtered | Where-Object Type -eq File).Count | Should -Be 1
    }
}

Describe 'safety, resume validation and exports' {
    It 'rejects a tampered manifest whose item path is outside its scope' {
        $m = [pscustomobject]@{ Schema=1;SiteUrl='https://contoso.sharepoint.com/sites/A';ScopePath='/sites/A/Docs';MatchMode='Prefix';Items=@(
            [pscustomobject]@{Id=[string][guid]::NewGuid();Type='File';Path='/sites/A/HR/secret.txt'}
        ) }
        { Test-RecoveryManifest -Manifest $m } | Should -Throw
    }
    It 'rejects a duplicate recycle-bin identity' {
        $id = [string][guid]::NewGuid()
        $m = [pscustomobject]@{ Schema=1;SiteUrl='https://contoso.sharepoint.com/sites/A';ScopePath='/sites/A';MatchMode='Prefix';Items=@(
            [pscustomobject]@{Id=$id;Type='File';Path='/sites/A/Docs/a.txt'},
            [pscustomobject]@{Id=$id;Type='File';Path='/sites/A/Docs/b.txt'}
        ) }
        { Test-RecoveryManifest -Manifest $m } | Should -Throw
    }
    It 'accepts a valid empty manifest' {
        $m = [pscustomobject]@{Schema=1;SiteUrl='https://contoso.sharepoint.com/sites/A';ScopePath='/sites/A/Docs';MatchMode='Prefix';Items=@()}
        Test-RecoveryManifest -Manifest $m | Should -BeTrue
    }
    It 'rejects an external query id scope' {
        { ConvertTo-RecoveryTarget -Url 'https://contoso.sharepoint.com/sites/A/Docs/Forms/AllItems.aspx?id=%2Fsites%2FB%2FDocs' } | Should -Throw
    }
    It 'rejects slashes in leaf names from untrusted bin metadata' {
        { Resolve-RecoveryItemPath -DirName '/sites/A/Docs' -LeafName '../HR/secret.txt' -CollectionPath '/sites/A' } | Should -Throw
    }
    It 'exports a zero-row CSV and can load the JSON manifest again' {
        $csv = Join-Path $TestDrive 'empty.csv'
        Export-RecoveryCsvSafe -Rows @() -Path $csv
        Test-Path $csv | Should -BeTrue
        $json = Join-Path $TestDrive 'manifest.json'
        $m = [pscustomobject]@{Schema=1;SiteUrl='https://contoso.sharepoint.com/sites/A';ScopePath='/sites/A';MatchMode='Prefix';Items=@()}
        Export-RecoveryJsonAtomic -Data $m -Path $json
        $loaded = Get-Content -LiteralPath $json -Raw | ConvertFrom-Json
        Test-RecoveryManifest -Manifest $loaded | Should -BeTrue
    }
    It 'neutralizes CSV formula injection in a filename' {
        $csv = Join-Path $TestDrive 'formulas.csv'
        Export-RecoveryCsvSafe -Rows @([pscustomobject]@{Path='=HYPERLINK("https://example.invalid")';Id='123'}) -Path $csv
        (Import-Csv -LiteralPath $csv)[0].Path.StartsWith("'=") | Should -BeTrue
    }
}

Describe 'throttle error classification' {
    It 'recognizes 429 from wrapped PnP error message' {
        (Get-RecoveryRetryAdvice -Exception ([System.Exception]::new('HTTP 429: Too Many Requests'))).Throttled | Should -BeTrue
    }
    It 'recognizes 503 from wrapped PnP error message' {
        (Get-RecoveryRetryAdvice -Exception ([System.Exception]::new('HTTP 503: Server too busy'))).Throttled | Should -BeTrue
    }
    It 'does not retry a generic unauthorized error' {
        (Get-RecoveryRetryAdvice -Exception ([System.Exception]::new('Unauthorized 401'))).Throttled | Should -BeFalse
    }
    It 'does not retry a generic not-found error' {
        (Get-RecoveryRetryAdvice -Exception ([System.Exception]::new('404 Not Found'))).Throttled | Should -BeFalse
    }
}

Describe 'live identity preflight' {
    It 'requires the stored and freshly read item paths, IDs, types and timestamps to match' {
        $id = [string][guid]::NewGuid()
        $saved = [pscustomobject]@{Id=$id; Path='/sites/A/Docs/file.txt'; Type='File'; DeletedUtc='2026-10-20T00:00:00.0000000Z'; DeletedByEmail='a@contoso.com'}
        $live = $saved.PSObject.Copy()
        Test-RecoveryLiveItem -Saved $saved -Live $live | Should -BeTrue
        $live.Path='/sites/A/HR/file.txt'
        Test-RecoveryLiveItem -Saved $saved -Live $live | Should -BeFalse
    }
}
