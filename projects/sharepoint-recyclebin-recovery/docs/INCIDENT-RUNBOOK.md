# Recovery incident runbook

## 0. Stop the incident and preserve evidence

- Verify this is **accidental SharePoint Online deletion**, not an active ransomware/malicious-actor incident. If malicious, coordinate with security, block compromised accounts/sessions, preserve logs and do not start recovery into an active compromise.
- Capture ticket ID, site/library owner, scope URLs, deletion UTC window, deleting user email/UPN, approximate file count, and requester authorization. Record any legal holds and retention requirements before making changes.
- Identify whether an entire **site collection**, **subsite**, **library**, or only **files/folders** was deleted. This tool recovers the last category only. Restore missing parent containers separately before attempting children.
- Check Microsoft 365 Service Health and SharePoint capacity. If content is missing due to move/rename or permissions, do not assume deletion.

## 1. Determine recovery source

| Incident | Primary path | Critical limit |
|---|---|---|
| Files and folders deleted | This utility, first + second stage | Standard bin retention **93 days total** from original deletion |
| A document was overwritten or altered | SharePoint version history, library rollback / Files Restore | Version/restore-window rules apply; current script **does not** restore previous versions |
| Deleted whole library/list | SharePoint site recycle bin / administrator | Restore parent library/list first |
| Deleted subsite or site collection | SharePoint admin site recovery | Site collection restoration is a separate admin workflow |
| Bin was purged, or deletion expired | Contact Microsoft Support promptly for supported recovery options; explore configured Microsoft 365 Backup / third-party backup / retention | Microsoft's additional **14 days after actual deletion** is for **site collection level support restore**, **not a guarantee for a single file** |
| OneDrive deletion | Scope to user's OneDrive `/personal/` site collection with permissions | Not a tenant-wide OneDrive recovery |

## 2. Permissions and platform

- PowerShell 7.4+; PnP.PowerShell stable (not v4 preview).
- Register your **own** Entra ID public client for interactive PnP and obtain admin consent for the SPO delegated permission. Initial example requests `AllSites.FullControl`; review least privilege with security and `Get-PnPCommandPermission` for your version.
- Operator must be a **site collection administrator** for full recycle bin enumeration. Tenant SharePoint admin role by itself is not enough.
- Confirm MFA and Conditional Access. The process uses interactive login to acquire a SharePoint access token and supplies the token to separate worker connections **in memory** only.
- The script operates within **one site collection per run**. Run separately for multiple sites; a subsite/library/folder URL scopes paths within its inferred parent collection. Test naming conventions and URL parsing for unusual managed paths or custom domains.

## 3. Prepare and inventory

1. Choose a **UTC** range, using `-DeletedFrom` inclusive and `-DeletedBefore` exclusive. E.g. one UTC day uses adjacent dates. User's local deletion time may cross midnight UTC; widen the range if uncertain.
2. Prefer full deleting-user UPN/email rather than a common short name; aliases and external identities can differ from the expected username.
3. Run a read-only preview; examine `inventory.csv` and `manifest.json`, stage, affected paths and estimated direct-file bytes. Folder row counts may understate their contents.
4. Review for overlaps with new content, current sync operations, unusual permissions, renamed libraries, nested/deleted parents, and deleted file versions.
5. Obtain approval from data owner and incident lead; decide `Skip` (recommended) vs `AllowRename` for path conflicts.

## 4. Execute in controlled batches

1. Start with 2 workers on a test library, inspect results, then choose up to 10 on a larger incident. **10 is a cap, not a guaranteed speedup.**
2. Use `-ResumePath ... -Apply`, type `RESTORE N` when prompted.
3. Folders restore parent-first sequentially, then file workers in bounded waves; each worker constructs its own PnP connection using a temporary in-memory SharePoint access token.
4. Review `results.json` after each wave; monitor 429/503 rate limiting, and reduce workers when throttling. Microsoft supplies `Retry-After`; the script honors it when readable and adds exponential backoff/jitter.
5. If interruptions occur, rerun the same saved manifest. The script skips recorded successful IDs and checks which items still appear in the recycle bin. **Missing from bin never proves restored to destination**; treat as manual verification.
6. Stop and escalate if repeated errors, failure to enumerate both stages, changes to the site's permissions, or substantial duplicate-name conflicts are observed.

## 5. Validate and close

- Compare expected item list to destination **paths and counts**, including folder subtrees; independently check random samples, high-risk large files, and folder hierarchies.
- Verify document versions/version history, metadata, permissions, check-in status, retention labels, links, sharing, and Microsoft 365/Teams integration where relevant. A restored file can return successfully while business content needs follow-up.
- Check duplicate names created by SharePoint, missing parent libraries, and user sync client effects.
- Save the operator, timestamp, filters, approval ticket and final result CSV in controlled incident storage. Do not paste private reports into GitHub issues.
- Escalate ambiguous `NeedsManualReview`, `ThrottledExhausted`, `ConnectionFailed`, `AbsentVerifyDestination`, and `SkippedExistingPath` records. Confirm recovered state before closing the incident.

## 6. No-downtime and performance expectations

- **No planned service cutover or DNS change.** The work restores in place and can run while users are online; however, writes/sync can cause collisions and inconsistent state during an active incident.
- Workers are bounded by the smaller of 10 and available files for a wave. Performance is dominated by Microsoft 365 backend latency, authentication, API throttling and how many paths must be checked. A count alone cannot yield a credible fixed duration.
- Microsoft commonly returns HTTP **429** or **503** on throttling and instructs clients to respect `Retry-After`. Default rate examples such as 3,000 requests/5 min/user are **not a safe guaranteed per-tool budget**. PnP's underlying CSOM calls may incur additional limits.
- `Skip` collision preflight approximately doubles simple per-file operations, and both bin stages must be inventoried. If enormous datasets or high business-criticality require stronger verification or service-level support, consider a backup/recovery product and a separate validation process.
