# Historical validation evidence — November 5, 2026

Publication update, November 9: this project is now included in `federico8a/powershell/projects/sharepoint-recyclebin-recovery`. The table below records the earlier validation session, including its then-current publication blocker. See [current status](../VALIDATION-STATUS.md).

This report supersedes the old October 29 not-run status. Reference implementation only; no 100% compatibility or live-success claim.

| Check | Result | Evidence |
|---|---|---|
| Source provenance | Corrected candidate from Migrations_Validation_2026-11-03.zip | Archive SHA-256 fdc2c3decab03990746f04a5a2624cacbf30ddf9f5b9834517cbe3e4aa663e1a; companion AUDIT.md read |
| PowerShell parser | PASS, 5 files, zero errors | evidence/2026-11-05-parser.log; PowerShell 7.4.13 Linux |
| Pester | PASS, 22 passed, zero failed/skipped | evidence/2026-11-05-pester.log; Pester 5.7.1 |
| Historical tests | November 3: 22 passed | evidence/2026-11-03-recovery-test.log |
| Secrets | No targeted pattern findings; source manually reviewed | evidence/2026-11-05-secret-scan.json; not proof of absence |
| Licensing documentation | Updated user rights, capacity, consumption boundaries | README; current Microsoft primary references checked November 5 |
| CI command | Fixed stale incompatible Pester invocation to -CI; pinned Pester 5.7.1 | .github/workflows/checks.yml; GitHub CI itself NOT RUN |
| GitHub publication | BLOCKED; repository absent | API 404 and account listing; integration lacks creation; no approved browser fallback |
| Live SharePoint/PnP integration | NOT RUN | No authorized test tenant identity/site; current PnP cmdlet surface not rechecked locally |

Source and test files are unchanged from the corrected candidate. Only README, workflow and validation evidence were updated. Parser/Pester checks ran against the prepared candidate; no code failures required repair.

## Reproduce

Use PowerShell 7.4.13 and Pester 5.7.1:

```powershell
$ErrorActionPreference = 'Stop'
Get-ChildItem . -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
    $tokens = $null; $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
    if ($errors) { throw ($errors | Out-String) }
}
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester ./tests -Output Detailed -CI
```

## Outstanding live acceptance

Use an explicitly authorized disposable SharePoint test site. Confirm delegated app consent, operator licensing/site collection admin access, capacity, installed PnP/runtime compatibility, first- and second-stage restoration, nested folders, collisions, 10-worker throttling/retry behavior, token expiry/refresh, interruption/resume and independent destination verification (content, versions, metadata, permissions and counts). Complete docs/VALIDATION-GATES.md and retain restricted incident evidence outside the repository. Command acceptance is not proof of recovered content. No production operation or paid-resource provisioning occurred.
