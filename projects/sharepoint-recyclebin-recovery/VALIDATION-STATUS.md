# Reference implementation — publication, November 9, 2026

Published within `federico8a/powershell` at `projects/sharepoint-recyclebin-recovery`.

The five PowerShell source/test files match the November 5 validated hashes: PowerShell 7.4.13 parser, zero errors; Pester 5.7.1, 22 passed and zero failed/skipped. Historical evidence is in [TEST-RESULTS.md](docs/TEST-RESULTS.md).

Publication changes adapt documentation and CI to the repository layout. PowerShell is unavailable in the publication workspace, so fresh parser/Pester and PnP compatibility checks run through the repository's SharePoint recovery workflow. Consult GitHub Actions for current results.

No live tenant or production operations have been performed. Complete the nonproduction validation gates before production use.
