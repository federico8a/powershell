# Licensing, prerequisites and cost planning (Canada)

Checked against Microsoft public documentation **2026-10-29**. Prices are public Canadian list figures for annual commitments; taxes, reseller discounts, special offers, Teams/no-Teams variants and enterprise contract terms vary.

## Baseline per-seat licensing

| Product | CAD/month/user | 100-user illustration (CAD/month) | Context |
|---|---:|---:|---|
| Microsoft 365 Business Basic (with Teams) | 9.50 | 950 | SharePoint and web apps, no installed desktop Office |
| Microsoft 365 Business Standard (with Teams) | 19.00 | 1,900 | Desktop Office plus SharePoint |
| Microsoft 365 Business Premium (with Teams) | 29.80 | 2,980 | Adds advanced management/security bundles |
| SPMT | 0 incremental | 0 | Free Microsoft migration tool with eligible destination M365 service |

Business seats: **300-user maximum** per business plan. Enterprise E3/E5 and SharePoint Plan 1/2 are options, but costs must be quoted against current Microsoft/licensing portal terms, country and contract. Do not double-license existing users who already have an entitled SharePoint Online service plan. A Microsoft 365 admin user must have appropriate role and target access. Power Automate flow owners must be appropriately licensed; premium connectors/RPA/on-prem gateway and higher-scale needs can add cost.

### Cost model to approve
- Seats = licensed users x actual applicable monthly SKU prices. Include temporary coexistence for source+target (different licensing models).
- SharePoint capacity: generally base **1 TB + 10 GB per qualifying licensed user**, 25 TB max per site collection (SKU/tenant exceptions). Example: 100 qualifying seats ≈2 TB pooled storage, BEFORE existing consumption. Confirm actual quota in tenant.
- Additional SharePoint storage is a separately purchased service when required; obtain an actual Canadian quote. Older versions/history can materially increase storage footprint. Version retention and compliance policies affect growth.
- **Source licensing**: continue SharePoint Server/Windows Server/SQL/CAL/Software Assurance/hosting/support costs until farm retirement; migration does not erase source license obligations.
- **Tooling**: SPMT = $0; optional ShareGate/AvePoint/Quest for complex branding, permissions, workflows and modernization: quote per migration scope and product licensing, no invented price. Trials are not approval for production use.
- **Labor & remediation**: migrations for forms, workflows, SPFx, search, integrations, hard-coded links and UAT; external consulting; after-hours cutover.
- **Infrastructure**: Windows migration host(s), CPU/RAM/SSD, outbound data, backup storage and optional custom Azure migration storage; network upgrades if required.
- **Security/compliance**: Purview retention/records/eDiscovery and audit requirements may require appropriate add-on/enterprise licenses. Legal holds and record retention must be reviewed before moving content.

## Operators, endpoints and tools
- Windows host: SPMT-recommended 64-bit quad-core, 16 GB RAM, 150 GB free SSD and 1 Gbps NIC; .NET Framework 4.6.2+, supported OS per Microsoft's prerequisites. For scripts use **Windows PowerShell 5.1**, not PowerShell 7.
- SPMT host must be able to reach both source SharePoint and SPO endpoints, Microsoft authentication, graph.microsoft.com and Azure queue/blob migration endpoints. Review documented firewall/proxy allowlist.
- On farm: SharePoint Server Management Shell and privileges to enumerate sites, webs, lists, features, applications, solutions and service dependencies. Export CSV under authorized secure storage.
- Destination: SharePoint Administrator for site administration, destination site-collection admin for content import; prefer least privilege, MFA and conditional access aware interactive auth. A separate Global Administrator is only justified for specific operations such as global term store migration when Microsoft requires it.
- SPO PowerShell module: Microsoft.Online.SharePoint.PowerShell. For PnP PowerShell, **pwsh 7.4+**, PnP.PowerShell module and registered Entra client ID with approved delegated/app permissions.
- Identity: provision users/groups first, map source domain accounts/SIDs to target UPNs; document orphaned principals, guests, AD security groups, service accounts, site collection admins.
- Target SharePoint tenant storage quota, custom domains, sharing, DLP, retention, sensitivity labels and conditional access policies approved before write.
- Supported sources: 2010/2013/2016/2019; assess Subscription Edition separately before promising compatibility. Validate authentication modes and any source-side third-party additions.
- Avoid hardcoded credentials. Use interactive prompts or approved secrets manager outside GitHub. Never paste tenant logs or production inventory into public repositories.

## Capacity/downtime estimation
- Theoretical seconds = Bytes_to_upload / Effective_bytes_per_second. This is ONLY a transport lower bound and excludes scans, source read contention, item overhead, throttling, permissions, retries, enumeration, workflow remediation and validation.
- Pilot at least one high-item-count and one customized site; record observed GB/hour, objects/hour and failed objects. Base wave estimates on pilot figures with contingency, not advertised line rate.
- Source can normally stay writable while initial sync runs; impose approved read-only freeze during delta and sign-off. Expect no guaranteed zero-downtime cutover.
- A full rollback requires retaining a tested, usable source plus a plan for writes made after go-live; there is NO automatic reverse migration.

## Pricing and documentation source URLs
- https://www.microsoft.com/en-ca/microsoft-365/business/with-teams-plans-and-pricing
- https://learn.microsoft.com/en-us/sharepointmigration/introducing-the-sharepoint-migration-tool
- https://learn.microsoft.com/en-us/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-limits
- https://learn.microsoft.com/en-us/sharepointmigration/spmt-prerequisites
- https://learn.microsoft.com/en-us/sharepointmigration/spmt-settings
- https://learn.microsoft.com/en-us/sharepointmigration/mm-file-size-limitations
