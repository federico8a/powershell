# SharePoint Server → SharePoint Online

Separate, repository-ready migration project. Reviewed 2026-11-09.

Recommended baseline: inventory → SPMT scan → remediation → pilot → seed copy →
controlled final delta → business acceptance. A SharePoint farm cannot be lifted
into SharePoint Online as a content database restore. Custom applications need
their own modernization workstream.

## Contents

- [Scenario selection](docs/01-scenarios.md)
- [Requirements and inventory](docs/02-requirements.md)
- [Licensing and CAD costs](docs/03-licensing-costs.md)
- [Timeline, cutover and recovery](docs/04-cutover.md)
- [Compatibility and limitations](docs/05-limitations.md)
- [Controls and acceptance](docs/06-controls-and-acceptance.md)
- [Offline calculator](docs/07-cost-and-time-calculator.md)
- [Microsoft references](docs/08-sources.md)
- `scripts/Export-SharePointInventory.ps1`: read-only farm inventory.
- `scripts/Invoke-SharePointMigration.ps1`: plan by default, explicit scan/migrate modes.
- `config/sites.example.csv`: source-to-destination site manifest.

## Quick start

1. Read the scenario and requirements documents. Confirm actual source version.
2. Copy the example manifest; enter approved URLs and source/destination ownership.
3. Run inventory in SharePoint Management Shell; protect its output.
4. Run offline planner; replace hypothetical rates with pilot measurements.
5. On the Windows SPMT workstation, run `Invoke-SharePointMigration.ps1 -ManifestPath
   .\config\sites.example.csv -TargetHost contoso.sharepoint.com` to review the plan.
6. Use `-Mode Scan` first; `-Mode Migrate` is a separate authorized write operation.
   The wrapper requires an explicit `-UserMappingPath` in either execution mode.
7. Accept the pilot and complete the runbook before production waves.

The user mapping file must use Microsoft's SPMT format and be validated in SPMT;
the manifest CSV is a different format. Source credentials are prompted at runtime.
Destination authentication uses the installed SPMT module's interactive flow; if
that build cannot satisfy your MFA/Conditional Access, use SPMT's supported GUI
authentication path. Do not bypass access policy or embed a password.

These scripts automate selected operational steps, not farm reconstruction,
custom workflow conversion or cloud-to-cloud migration. See VALIDATION.md.
