# SharePoint Server to SharePoint Online | Enterprise Migration Runbook & Automation

A CMD-first, PowerShell-led, risk-controlled migration project for **SharePoint Server (on-premises) to SharePoint Online**. Supports assessment, farm inventory, target provisioning, migration waves, incremental reruns, comparison reports, cutover and acceptance. Documented against Microsoft guidance checked **2026-10-29**.

> **Engineering boundary:** This is an implementation starter, not a one-click identical transplant of a SharePoint farm. SPMT copies *supported* sites, content and settings. On-prem farm services, server code, custom workflows/forms, integrations and certain SharePoint groups/settings must be redesigned and tested. NO content has been migrated by publishing this repository.

## Architecture and selection

- **On-prem SharePoint PowerShell**: authoritative inventory while run on a farm server as a farm administrator.
- **SPMT + Microsoft.SharePoint.MigrationTool.PowerShell (Windows PowerShell 5.1)**: scan, move site content/libraries/lists, supported site settings, metadata, permissions, version history, classic navigation and supported web parts.
- **SharePoint Online Management Shell**: inspect and provision site collections when the target architecture has been approved.
- **PnP PowerShell (PowerShell 7.4+)**: compare destination list inventory and implement APPROVED post-migration site adjustments; site template support is not equivalent to copying a farm.
- **Microsoft Graph**: Entra identity/group prerequisites, reports and selected SPO operations; NOT the bulk SharePoint Server site/content migration engine.
- **Power Automate / SPFx / third-party**: reimplement features that cannot be migrated natively. See docs/feature-matrix.md.

Mermaid diagram: [Architecture](docs/architecture.md).

## Supported source versions
Microsoft documents SPMT source support for SharePoint Server **2010, 2013, 2016, 2019**, SharePoint Foundation 2010/2013, and file shares. Do **not** presume Subscription Edition or third-party integrations are supported without testing current vendor guidance.

## Repository

- run.cmd — CMD entry point (the operator invokes PowerShell through CMD)
- config/sites.example.csv — sanitized waves and source/target site collection mapping
- config/user-mapping.example.csv — SPMT mapping (NO HEADER in real mapping)
- scripts/00-Preflight.ps1 — local version, module and manifest checks
- scripts/01-Inventory-OnPrem.ps1 — farm-side site/web/list/feature inventory (read-only)
- scripts/02-Provision-Targets.ps1 — dry-run by default; gated site creation
- scripts/03-Run-SPMT.ps1 — scan, initial and delta with safety confirmation
- scripts/04-Validate-Online.ps1 — target site/list counts and comparison flags; never claims perfect fidelity
- docs/licensing-and-prerequisites.md — CAD price snapshot, infrastructure, permissions, extra costs
- docs/feature-matrix.md — explicit native/conditional/rebuild classification
- docs/cutover-runbook.md — waves, freeze, incremental sync, rollback, RACI and downtime
- docs/acceptance-and-tests.md — sign-off criteria and evidence
- docs/sources.md — primary Microsoft docs and dated references

## First-time operator commands (Windows CMD)

1. Download latest GA **SharePoint Migration Tool** and install on an approved Windows migration host. Use **Windows PowerShell 5.1**, not pwsh 7, for SPMT cmdlets. Install SPO Management Shell as needed. PnP validation uses PowerShell 7.4+ and an Entra registered client ID.
2. Copy config/sites.example.csv to config/sites.csv. Enter actual SOURCE and TARGET site collection URLs, valid owner UPN, per-wave classification. Never commit private real inventory or credentials. See docs/feature-matrix.md before mapping any custom site.
3. Execute on the migration host:

       run.cmd preflight
       run.cmd scan W1
       run.cmd provision-preview W1
       run.cmd provision-apply W1
       run.cmd initial W1

4. On the **SharePoint Server farm** (elevated SharePoint Management Shell / farm admin) run:

       run.cmd inventory

5. During approved read-only freeze, rerun SAME source/target mapping for last incremental round:

       run.cmd delta W1

6. With PnP PowerShell 7.4+, client application ID, and source inventory CSV exported to migration host:

       set PNP_CLIENT_ID=<registered-Entra-app-client-id>
       run.cmd validate W1

7. Review generated CSV, SPMT logs, business-user UAT, link remediation and sign-off. Do not decommission source until rollback window is closed.

## Safe defaults & warnings

- Provisioning is **dry-run** unless provision-apply explicitly selected.
- SPMT migration requires interactive operator confirmation and displays source/target mapping.
- Credentials are prompted interactively; passwords, certificates and tokens are **not** stored in scripts or config.
- SPMT session is **not forcibly replaced** (no -Force); run only one SPMT session per user/host. Clear old completed sessions deliberately with Unregister-SPMTMigration.
- SPMT scan does not authorize skipping environment-specific pilot migrations.
- Do not rename, reorganize or modify destination files between migration passes.
- A post-cutover redirect or DNS change for custom intranet links is OPTIONAL and must be assessed separately. SharePoint Online tenant hostname and Microsoft 365 MX records normally do **not** change for this workload-only migration.
- Migration job completion is not equivalent to validated zero data loss; unsupported types, versions, permissions, deleted data, workflow histories and complex integrations require explicit disposition.

## Licensing summary (CAD, Canada, annual-billed list, checked 2026-10-29)

| Product | Indicative recurring price, before taxes |
|---|---:|
| SPMT | $0 incremental tool license |
| Microsoft 365 Business Basic, with Teams | $9.50/user/month |
| Microsoft 365 Business Standard, with Teams | $19.00/user/month |
| Microsoft 365 Business Premium, with Teams | $29.80/user/month |

Business plans have a 300-user cap; Enterprise, SharePoint standalone, E5/Purview, storage add-ons, Power Automate premium connectors and paid migration products require separate SKU and pricing assessment. Refer to docs/licensing-and-prerequisites.md and Microsoft official price pages. **No licenses have been purchased.**

## Sample downtime policy

Initial bulk migration: usually **no source outage**. Final sync: source placed into **read-only/change freeze** for an estimated window calculated from actual pilot throughput, residual changes, errors and UAT. A sample 4-hour freeze is an EXAMPLE, **not a guarantee**. There is no automatic zero-downtime cutover or RTO without tested results.

## Roles and gates

Sponsor approves downtime and scope; owners approve source/target mappings; identity owner signs off UPN/group mappings; security/compliance approves permissions, retention and external sharing; migration operator runs scans and SPMT; business owners sign UAT; incident manager controls go/no-go and rollback. See docs/cutover-runbook.md.

## References

Microsoft official sources are linked in docs/sources.md. This repository is not affiliated with Microsoft. Review product limitations and license terms before production use.
