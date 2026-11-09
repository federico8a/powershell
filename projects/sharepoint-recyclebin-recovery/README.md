# SharePoint Online Recycle Bin Recovery — PowerShell / 10 workers

> **Status:** Reference implementation with offline validation; **not validated in a live tenant**. Use on a test site first. `-Apply` makes real changes. Supports **SharePoint Online**, not SharePoint Server on-premises.

A CLI-first, incident-response utility for recovering deleted files and folders. A site collection administrator pastes a **site, subsite, library, folder, or file URL**. The tool inventories **both recycle bin stages**, filters by **deletion date (UTC) and/or deleting user**, prints total matching entries and direct-file byte size, and writes a reusable JSON manifest, CSV inventory and **`summary-by-date-user.csv`** grouped by UTC date, deleting user, item type and recycle-bin stage. After explicit approval it restores folders **parent-first** and files using **up to 10 PowerShell 7 parallel workers**.

**Important:** These are **recycle-bin entries**, not a complete scan of everything inside deleted folders. A deleted folder is often a single entry containing a subtree; its embedded file count/bytes cannot safely be inferred from the bin metadata. A folder restore can restore more data than the individually visible file rows. Parent and descendant folders are inventoried and rechecked between path-depth levels to avoid repeatedly restoring entries already removed by an ancestor restore. Do **not** treat the inventory's direct-file count as the number of all descendants.

## Quick start

Prerequisites: PowerShell **7.4+**, PnP.PowerShell stable module (v3.x; test with your installed version), Microsoft 365 account with **site collection administrator** access to the affected site, and a **customer-owned Entra app registration** with consented **SharePoint delegated** permission (`AllSites.FullControl` for the provided setup). The app is not a replacement for the user's site collection admin role. Avoid using a global admin day-to-day. Use an access-reviewed incident operator account.

```powershell
# One-time, run on an administrator workstation with pwsh 7.4+.
Install-Module PnP.PowerShell -Scope CurrentUser

# Authorized Entra administrator registers ONE app and consents; record its client ID.
Register-PnPEntraIDAppForInteractiveLogin `
  -ApplicationName 'SPO-RecycleBin-Recovery' `
  -Tenant 'contoso.onmicrosoft.com' `
  -SharePointDelegatePermissions 'AllSites.FullControl'

# Preview: interactive prompts (site URL, dates, deleting user).
./Invoke-SharePointRecovery.ps1 -ClientId '11111111-1111-1111-1111-111111111111'

# Or preview explicitly (UTC day from 2026-10-20 inclusive to 2026-10-21 exclusive):
./Invoke-SharePointRecovery.ps1 `
  -ClientId '11111111-1111-1111-1111-111111111111' `
  -TargetUrl 'https://contoso.sharepoint.com/sites/Finance/Shared%20Documents' `
  -DeletedFrom '2026-10-20' -DeletedBefore '2026-10-21' `
  -DeletedBy 'person@contoso.com' -Workers 10

# Later, use the printed report path and explicitly authorize the saved inventory:
./Invoke-SharePointRecovery.ps1 `
  -ClientId '11111111-1111-1111-1111-111111111111' `
  -ResumePath './reports/20261029_120000_000' -Apply -Workers 10
```

On `-Apply`, the script requires `RESTORE N` typed exactly for **N remaining items**; otherwise nothing is modified. `-ResumePath` rechecks live recycle-bin IDs before restoring pending entries. Re-running with a saved manifest does **not** silently include newer deletions. To discover them, create another inventory.

### URL examples

- Site: `https://contoso.sharepoint.com/sites/Finance`
- Subsite: `https://contoso.sharepoint.com/sites/Finance/Reports`
- Library: `https://contoso.sharepoint.com/sites/Finance/Shared%20Documents`
- Folder: `https://contoso.sharepoint.com/sites/Finance/Shared%20Documents/2026`
- One file: `https://contoso.sharepoint.com/sites/Finance/Shared%20Documents/budget.xlsx` (automatically uses exact URL match)
- A library *Forms/AllItems.aspx* URL containing an `id=` query parameter pointing to the folder is supported; otherwise paste the direct folder URL.

`-MatchMode Prefix` includes descendants; `-MatchMode Exact` restores a single matching path. `-MatchMode Auto` (default) guesses files by a filename extension; **for folders with dots in their names, pass `-MatchMode Prefix`**. Paths match on boundaries (for example, a Finance scope excludes FinanceArchive). URL encoding and site-collection URL inference apply to standard `/sites/`, `/teams/`, `/personal/` paths and root collections. An individual OneDrive is a `/personal/...` site collection, not a tenant-wide OneDrive scan.

### Additional parameters

| Flag | Default | Behavior |
|---|---|---|
| `-DeletedFrom yyyy-MM-dd` | any | UTC date inclusive |
| `-DeletedBefore yyyy-MM-dd` | any | UTC date exclusive; **to select one day, use next day** |
| `-DeletedBy` | any | Exact email/UPN preferred; short-name matches `DeletedByName` or email local part (may be ambiguous) |
| `-Workers` | `10` | Up to 10 file workers; automatically halves next wave on throttling and increases slowly afterward |
| `-BatchSize` | `200` | Files per wave; token refreshed between waves, results saved after each wave |
| `-RowLimit` | `100000` | Applied separately to each recycle-bin stage; aborts on equality to avoid known truncated inventory |
| `-MaxRetries` | `6` | Retry only recognized 429/503 throttling with exponential backoff, jitter and `Retry-After` when extractable |
| `-CollisionPolicy` | `Skip` | Detect existing target path and **skip**; `AllowRename` explicitly delegates collision naming to SharePoint |
| `-Apply` | off | Explicitly opt in to restore; typed confirmation still required |
| `-ResumePath` | none | Uses saved manifest and results, rechecks IDs |

The tool does not need a separate Graph SDK or Graph permission. It uses PnP's SharePoint APIs for recycle-bin coverage; the Microsoft Graph API for enumerating a general SharePoint site's bin is **beta** at the time of design. Graph v1.0 recycle-bin coverage is not a drop-in equivalent for this workflow.

## Project structure

```text
Invoke-SharePointRecovery.ps1    # interactive entry point, inventory, approval, parallel wave orchestration
src/Recovery.Common.psm1         # path handling, UTC/date/user filtering, exports
src/Restore-Worker.ps1           # per-runspace SPO connection, collision preflight, restore and throttle retry
reports/                         # generated locally, ignored by git (sensitive audit evidence)
tests/Recovery.Common.Tests.ps1  # Pester tests of deterministic helper logic
docs/INCIDENT-RUNBOOK.md         # approvals, risks, validation, rollback alternatives
docs/VALIDATION-GATES.md          # 25-point live-tenant acceptance matrix; release gates
.github/workflows/checks.yml     # PowerShell parsing and Pester on Ubuntu
```

## Safeguards and known limitations

1. **Read-only by default.** Inventory/preview first; use `-Apply` only after reviewing the scope and validating the paths.
2. **Site collection scope matters.** Deleted subsites/sites or libraries themselves are **not** recovered by this tool. Restore the parent/site/library first via the appropriate SharePoint admin recovery path; run this utility for files/folders once the container exists.
3. **Folder semantics.** A folder entry may encapsulate all children. It is restored sequentially before file entries. The tool rescans the bin after folders and flags vanished descendants as `AbsentVerifyDestination`, **not guaranteed success**. Parent-first restoration avoids predictable races. Independently check resulting folders.
4. **Existing targets.** `Skip` prevents intentional overwrite/name-collision surprises but adds an existence lookup for every item and can throttle. Other writes/users can race between check and restore. With `AllowRename`, SharePoint may append a number to a restored filename; reconciliation is essential.
5. **Partial results.** Each wave writes `results.json` and safe-for-spreadsheet `results.csv`. A crash inside a wave can leave successful server operations unlogged; on resume, missing bin IDs are flagged for manual verification. CSV is a display artifact; JSON is authoritative. No passwords or tokens are written to disk.
6. **Timeouts and ambiguous outcomes.** Only known 429/503 errors are retried. Other exceptions are recorded as `NeedsManualReview`, not blindly retried. `RestoreCommandSucceeded` means the cmdlet returned successfully, **not** a post-restore file/version/permission verification.
7. **Concurrent edits and clients.** A restore is online; no planned SharePoint downtime. Coordinate with owners to pause destructive bulk operations, sync churn, and renames during an incident where possible.
8. **Enumeration cap.** Large bins may require higher `-RowLimit`; aborting at the limit prevents claiming a complete count when visibly truncated. Very large collections can still stress CSOM/server paging—test in a representative collection. Snapshot may change while inventory is built.
9. **Reporting data is sensitive.** Reports contain paths, user emails and deletion dates. Use restricted storage; do not commit reports to a public repo. Keep access audit records and apply your organization's retention/deletion policy.
10. **No guarantee of full data recovery.** Deleted versions, list items, list/library/site/subsite objects, permanently purged content, Preservation Hold contents, retention holds, inaccessible sites, and expired items require other procedures. Files inside a deleted folder may be recovered as part of the folder even when not individually counted.

## Testing and release gates

The November 3 audit records 22 passing Pester tests and successful PowerShell parsing. See [current validation evidence](docs/TEST-RESULTS.md) for the November 5 recheck and exact runtime. These offline tests do not establish live recovery success or 100% compatibility. CI must run after publication, and the controlled nonproduction acceptance matrix remains mandatory before production use.


```powershell
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser
Invoke-Pester ./tests -Output Detailed -CI
```

Automated Pester tests cover path/URL parsing, date/user filtering, manifest boundaries, CSV injection protection, throttle classification and static safeguards. They **do not** establish SharePoint/Entra live integration, nor verify actual restoration. Live validation in a nonproduction site must test first-stage, second-stage, nested folders, duplicate names, user and date filtering, throttling at 10 workers, long-running token refresh, interrupted jobs/resume, and permissions. See the incident runbook and [release validation checklist](docs/VALIDATION-GATES.md).

## Licensing and dependencies

| Category | Requirement and cost boundary |
|---|---|
| Per-user service rights | Internal users accessing SharePoint need an assigned license including SharePoint Online. Validate the incident operator's applicable entitlement as well as site collection administrator access. One administrator license does not license all users. App consent does not grant user licensing or site administrator rights. |
| Tenant and site capacity | SharePoint storage is a shared tenant pool with separate site quotas; it is not a per-user access entitlement. Confirm available tenant/site capacity and recycle-bin usage before recovery. Capacity depends on plan, purchased licenses and storage add-ons; do not assume a universal quota for every plan. |
| Consumption and optional services | This script uses PnP recycle-bin commands and does not enable Microsoft 365 Backup, Azure resources or paid storage. Optional Microsoft 365 Backup uses consumption billing, and configured pay-as-you-go SharePoint overage storage can incur charges. Existing paid services/storage policies may still apply. No paid resources are provisioned by this project. |
| Tool license | Project source is MIT; PnP.PowerShell is open source. Neither replaces Microsoft service entitlements. Retention/eDiscovery, advanced identity controls and third-party backups require their own applicable rights and configuration. |

Licensing references checked November 5, 2026 (no price quote or procurement certification):
- [SharePoint service description and user licensing](https://learn.microsoft.com/en-us/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-service-description)
- [SharePoint storage planning](https://learn.microsoft.com/en-us/sharepoint/sharepoint-storage-planning)
- [Microsoft 365 Backup consumption pricing](https://learn.microsoft.com/en-us/microsoft-365/backup/backup-pricing)

## Primary sources (checked October 29, 2026)

- [PnP Get-PnPRecycleBinItem](https://pnp.github.io/powershell/cmdlets/Get-PnPRecycleBinItem.html)
- [PnP Restore-PnPRecycleBinItem](https://pnp.github.io/powershell/cmdlets/Restore-PnPRecycleBinItem.html)
- [PnP Get-PnPAccessToken](https://pnp.github.io/powershell/cmdlets/Get-PnPAccessToken.html)
- [PnP app registration for interactive login](https://pnp.github.io/powershell/cmdlets/Register-PnPEntraIDAppForInteractiveLogin.html)
- [PnP installation prerequisites](https://pnp.github.io/powershell/articles/installation.html)
- [Microsoft restore/recycle-bin retention](https://learn.microsoft.com/en-us/sharepoint/restore-deleted-items-from-site-collection-recycle-bin)
- [Microsoft throttling, 429/503, Retry-After](https://learn.microsoft.com/en-us/sharepoint/dev/general-development/how-to-avoid-getting-throttled-or-blocked-in-sharepoint-online)
- [Microsoft restore destination/collision behavior](https://support.microsoft.com/en-us/sharepoint/admin/restore-items-in-the-recycle-bin-that-were-deleted-from-sharepoint-or-teams)
- [Graph site recycleBin list API: beta](https://learn.microsoft.com/en-us/graph/api/recyclebin-list-items?view=graph-rest-beta)

## License

MIT. No affiliation with Microsoft or PnP. Review access/scopes and service rules before production use.

## Download and run

This project is published under `projects/sharepoint-recyclebin-recovery` in the [PowerShell repository](https://github.com/federico8a/powershell).

```powershell
git clone https://github.com/federico8a/powershell.git
Set-Location powershell/projects/sharepoint-recyclebin-recovery
# Follow Quick start above; preview is the default.
```

Repository CI is defined in `../../.github/workflows/sharepoint-recovery-ci.yml`.
Generated incident reports remain local and are excluded by `.gitignore`.

## Current validation status

See [VALIDATION-STATUS.md](VALIDATION-STATUS.md). This is an offline-tested candidate; live migration and recovery remain unverified.
