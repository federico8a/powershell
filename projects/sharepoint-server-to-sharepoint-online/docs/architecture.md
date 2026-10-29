# Reference architecture

\`\`\`mermaid
flowchart LR
 A[SharePoint Server farm SQL + content DB] --> B[On-prem inventory / source backups]
 A --> C[SPMT Windows host / PS 5.1]
 B --> D[Scope / mapping / remediation register]
 D --> E[Approved target site design]
 E --> F[SharePoint Online sites]
 C -->|scan then bulk then delta| F
 G[Microsoft Entra ID / license / identities] --> F
 H[Power Automate / SPFx / PnP modernization] --> F
 F --> I[Validation / UAT / audit / signoff]
 I --> J{Go live?}
 J -->|yes| K[Redirect bookmarks / search / intranet links]
 J -->|no| L[Preserve source read-only or roll back to source]
\`\`\`

## Control plane
- CMD calls Windows PowerShell 5.1 SPMT migration orchestration. It does not copy binaries itself.
- Source SharePoint Management Shell inventories farm objects, including customizations requiring remediation.
- SPO Management Shell provisions approved site collections. Avoid automatically stamping classic templates onto sites requiring modernization.
- Microsoft Graph provisions or checks Entra principals where appropriate. Graph alone does not provide a fully faithful on-prem site/content migration path.
- PnP PowerShell validates site lists and supports explicit modern rebuild tasks. It requires a proper Entra app registration and PowerShell 7.4+.

## Network and data
- Migration host must reach source web applications and permitted Microsoft 365/Azure migration service endpoints (HTTPS 443). Validate proxy, TLS, bandwidth, throttling, firewall allowlists, authentication and internet egress.
- Confirm on-prem SQL/content database backups + SharePoint farm backup, recovery tests and retention. SPMT is NOT a backup.
- Stage migration in waves and monitor Microsoft 365 service health; do not assume unlimited throughput.
- Microsoft-managed SPMT staging is included with tool path; custom Azure staging may incur Azure storage/transactions/egress costs.

## Site architecture
Maintain classic hierarchy initially ONLY when justified by dependencies; prefer modern, flat site collections and hubs when business owners approve restructuring. Modernization and content migration are separate design decisions and may need additional tooling.
