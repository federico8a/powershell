# Evidence-driven validation and sign-off

Never assert "zero data loss" from green SPMT status alone. Compare an independently produced source inventory with destination evidence; exceptions must have a signed disposition.

## Automation evidence
- Source inventory: source-sites.csv, source-webs.csv, source-lists.csv, source-features.csv from on-prem server. Inventory scripts read only; older and custom farm APIs can require patch-specific adjustments.
- Destination: target-sites.csv and target-lists.csv per wave from PnP PowerShell validation. List comparison report lists items for review; no item-by-item hashes are computed.
- SPMT: session status, per-task errors/warnings, scanned/migrated/skipped item metrics, local logs at %APPDATA%\Roaming\Microsoft\MigrationTool. Export audit evidence to restricted storage.

## Manual and business tests
| ID | Required acceptance | Owner / evidence |
|---|---|---|
| A01 | All expected sites/subsites resolve at agreed target URLs | Site owner, site map |
| A02 | All expected libraries/lists are present; mismatches investigated | Migration lead, source vs target counts |
| A03 | File sample by site: size, filename, binary/hash downloaded and compared where high risk | Data owner, sample hash report |
| A04 | Version trees, authors, modified/created stamps and metadata spot checks | Records owner, screenshots/log |
| A05 | Confidential, read-only and external access tested as non-admin users | Security, access matrix |
| A06 | Taxonomy, content types, lookup columns, navigation and views work | App owner, UAT |
| A07 | Embedded links, page layouts, custom web parts/images, forms work or signed remediation exists | Site owner, defect tracker |
| A08 | Workflows / Power Automate triggers produce expected result; history retention addressed | Process owner, flow logs |
| A09 | Search, Teams tabs, OneDrive clients and external integrations tested | Collaboration lead |
| A10 | Record retention, labels, DLP, audit and guest sharing enforce approved target policy | Compliance |
| A11 | Final delta complete; source freeze timestamp, SPMT error reports, residual delta disposition documented | Change manager |
| A12 | Rollback tested and source kept according to agreed retention; stakeholder go-live approval | Incident manager |

### Gate threshold
Every **P1/P2** data loss, permission exposure or business-blocking defect is a NO-GO. Accept lower-severity exceptions only with tracked owner, due date, compensating control and approval. Count equality is a signal, not proof of binary parity. List item counts may differ due to hidden/system items or nonmigration of unsupported types.

### Suggested results register (keep outside public repo)
Site URL | Test ID | Baseline | Observed | Status PASS/FAIL/EXCEPTION | Evidence file/link | Owner | Date | Remediation / Decision

For regulated content consider a distinct, audited content-integrity sampling solution, permitted by privacy/security policy. Never download sensitive content to developer workstations as part of informal testing.
