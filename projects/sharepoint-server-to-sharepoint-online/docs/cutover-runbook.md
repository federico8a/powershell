# Migration waves, downtime, cutover and rollback (operator runbook)

## Executive decision
Recommended model: **prestage (source live) -> validate -> freeze source writes -> final delta -> UAT and security checks -> go-live -> hypercare -> source retention and retirement**. No blanket DNS swap for SPO; user links, intranet entry points and custom-domain routing need individualized plans.

## Governance and readiness
- Signed scope and business owner for EVERY site, subsite and library; inventory totals, excluded items and exception disposition recorded.
- Source farm farm/SQL backups, tested restore, storage capacity, health, antivirus performance and change management window.
- Tenant identities, UPNs, licensing, user mapping, custom groups, guests, permissions, target quota, Purview policies and external sharing approved.
- Approved information architecture: classic to classic (dependency-safe) versus modern flat sites/hubs; consistent URL mappings and old/new hyperlinks inventory.
- Pilot on low-risk and high-complexity sites, measure throughput/errors, version/permission accuracy and business functional tests. Recalculate actual wave windows.
- Cutover owner + deputy, comms lead, technical lead, site owners, helpdesk and emergency contacts assigned. Freeze/rollback authority explicit.
- Never rely on SPMT alone for farm solutions, custom web parts, workflows, SQL apps or access policy migration; tracked remediation with before/after tests.

## Example timeline (replace with measured plan)
| Relative date | Action | Source writes | Gate |
|---|---|---|---|
| T-30 to T-14 days | Discover/inventory, supported-feature matrix, select wave and pilot, capacity/license audit | On | Architecture and exception sign-off |
| T-14 to T-7 | Provision identities/sites, SPMT scan and fix blockers, first content pass, remediation & user training | On | Pilot data and security PASS |
| T-7 to T-2 | Incremental pass, permissions spot-check, broken link register, pre-cutover baseline, backup/recovery test | On | No unresolved P1/P2 blocker |
| T-24h | Notify users, make runbook/rollback contacts available, verify target auth, client links, license compliance | On | Go/no-go |
| T-0 | Pause automations/connectors, enforce source read-only or freeze permissions and document exact timestamp | **Off/read-only** | Freeze effective |
| T+0 to T+2h (illustrative ONLY) | Final SPMT delta, inspect errors/retries, sample versions/data/permissions | Off/read-only | Reconciliation PASS |
| T+2 to T+4h (illustrative ONLY) | Business UAT, security sharing checks, update bookmarks/intranet links, release users to target | Off/read-only | Signed go-live |
| T+1–14 days | Monitor errors, permissions, links, access, sync clients and support queue | Source remains read-only | Hypercare exit |
| T+30+ | Archive source per retention, confirm final disposal authorization, decommission | Source off after approval | Compliance sign-off |

**Actual outage/downtime**: data pre-copy typically avoids source outage. **Write downtime** begins at freeze and ends after final pass and UAT. Hours/days depend on residual change volume, item count, throttling, permissions, remediation and pilot throughput. Page access may remain available in source read-only mode; user write operations are unavailable. Measure and communicate actual RTO and RPO, do not promise zero.

## Operator steps, per wave
1. Fill config/sites.csv (do not commit actual production inventory), get authorization and secure source backups.
2. On farm: run.cmd inventory; scope and reconcile all site collections and webs. Save outputs to controlled location.
3. Migration host: run.cmd preflight; run.cmd provision-preview W1; review templates and quotas; run.cmd provision-apply W1 only with approval. Manual/modern sites must be created through approved workflows before import.
4. Run.cmd scan W1 and sign off reports and scan issues. After archiving reports, run.cmd reset-session W1 (ONLY for the completed scan-only session).
5. run.cmd initial W1 (new session). Retain the same session for all delta rounds; export logs, retry failures and re-run checks as needed, without changing target paths.
6. Enforce documented freeze on source **with actual SharePoint permissions / application behavior**; do not presume scripts here make the source read-only automatically.
7. run.cmd delta W1; inspect SPMT reports; run.cmd validate W1; complete docs/acceptance-and-tests.md.
8. Go/no-go; update intranet URL redirects, bookmarks, search links, apps, Teams channels and user communications. SPO hostname is not automatically identical to old intranet FQDN; no MX/Exchange change.
9. Keep source read-only until rollback period ends. Do not grant write on both source and target.

## Go / no-go gates
- G1: all in-scope locations mapped and inventories signed.
- G2: destination identities/permissions/retention/storage ready; admin access and licensing confirmed.
- G3: migration logs show no unresolved blocking errors; evidence of source-target reconciliation for every critical site.
- G4: business owner verified sampled high-value files, version history, list metadata, workflows and links.
- G5: security owner verified restricted libraries, guests, sharing, labels and audit.
- G6: rollback decision authority, source snapshot, RTO and outbound communication ready.

## Rollback/abort
- If pre-go-live validation fails: **do not release target writes**. Keep/readmit source writes under incident authority, suspend destinations, notify users, fix and reschedule. Resume source only after preventing split-brain.
- If after go-live: compare *new target writes* since go-live and plan controlled reverse transfer/export to source if feasible; SPMT is NOT a bidirectional synchronizer. Restore source from known backups if necessary, document possible data delta, legal retention, link impacts and user communications.
- Revert bookmark/redirect/intranet app paths if configured; SPO site URL changes are not the same as a DNS rollback.
- Preserve SPMT task reports, mapping manifest, freeze/change timestamps, incident notes, UAT tests, signatures.

## Site-level special plans
- Critical applications: switch connections only after all connectors, external data and auth tested.
- Classic publishing/InfoPath/workflows: choose replacement or defer with written acceptance.
- Permissions: test confidential users as actual users (not only admins).
- Remote clients: OneDrive sync, Power BI data sources, third-party apps and API endpoints can retain stale links.
