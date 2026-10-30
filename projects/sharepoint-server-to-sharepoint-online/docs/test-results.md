# Quality assurance and release gates

Last reviewed: 2026-10-29 (Atlantic time).

## Source-code verification already performed
- Verified public repository files and folder layout.
- Audited Windows CMD goto labels, no missing or duplicated labels.
- Compared Register-SPMTMigration parameters used by the script against Microsoft Learn's official parameter list. No invalid named parameters detected in the current parameter hashtable.
- Verified that preflight rejects duplicate mappings, incorrect targets, unknown provisioning modes and malformed quotas.
- Confirmed no hardcoded passwords or plaintext password conversion in authored PowerShell scripts.
- Confirmed explicit user prompts before migration/provisioning, a safe provision-preview path, incremental session mapping hashes and a required cutover freeze confirmation.
- Fixed two issues found by static review: the PowerShell cmdlet's default MigrateTermGroups behavior is now explicitly disabled unless separately approved, and SPMT running/unknown states cause reset/delta operations to fail closed.
- Removed blanket ExecutionPolicy Bypass from CMD launcher so enterprise PowerShell execution policy remains in force.

## Automated Windows CI
- Workflow: https://github.com/federico8a/powershell/actions/workflows/sharepoint-migration-ci.yml
- Tests: tests/SharePointMigration.Tests.ps1 contains 14 Pester cases covering basic manifest acceptance, invalid inputs, duplicate mapping, demo target blocking, dry-run, missing session, manifest checksum mismatch, and non-completed reset prevention.
- CI runs Windows PowerShell 5.1, PSScriptAnalyzer severity Error, Pester 5, and CMD preflight smoke test on isolated sample manifest.
- Actual Pester test pass/fail results MUST be read from GitHub Actions at release time. Never state that tests have passed without a successful run for the released commit.

## Incomplete coverage — blocks any 100% claim
- SPMT session status, delta behavior, migration endpoint authentication and performance have not been tested against an authorized real SharePoint Server farm / M365 tenant.
- Source-to-target data correctness requires full wave test: site collections, subsites, lists, folders, item attachments, binary content/hash samples, all file versions, custom permissions, audit fields, identity mapping, navigation, taxonomy, custom web parts, workflows and flows, retention and DLP. Pester mocks cannot prove this.
- Error handling under throttling, package error thresholds, retries and network failures requires a staged integration test.
- A freeze/recovery/rollback exercise and critical business UAT signoff must occur before any production cutover.
- No customer credentials or production tenant connections have been supplied for those tests.

## Reproducible operator checks
From an isolated Windows clone, install trusted Pester 5 and PSScriptAnalyzer from PSGallery after corporate policy review, then execute:

    Import-Module Pester -MinimumVersion 5.0
    Invoke-ScriptAnalyzer -Path .\scripts -Recurse -Severity Error
    Invoke-Pester -Path .\tests -Output Detailed

The command-line runner must be tested with an example manifest, not production tenant settings.

## Official vendor references
- https://learn.microsoft.com/en-us/powershell/module/microsoft.sharepoint.migrationtool.powershell/register-spmtmigration?view=spmt-ps
- https://learn.microsoft.com/en-us/sharepointmigration/overview-spmt-ps-cmdlets
- https://learn.microsoft.com/en-us/sharepointmigration/spmt-create-task
- https://learn.microsoft.com/en-us/sharepointmigration/what-is-supported-spmt
