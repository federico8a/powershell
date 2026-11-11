# Scope and limitations

| Object / feature | Treatment | Validation obligation |
|---|---|---|
| Files, folders, supported lists | SPMT baseline | Counts, representative hashes/downloads, metadata and skips |
| Version history | Explicit settings | Confirm version policy and retained version samples |
| Permissions | Mapping plus preservation settings | Group membership, unique ACLs and negative-access tests |
| Content types / taxonomy | Configure and pilot | Term IDs, lookups, dependent fields, administrator privileges |
| Out-of-box pages/web parts | Supported subset | Visual and functional comparison; not automatic modern-page conversion |
| WSP farm solutions / full-trust code | Redesign | SPFx/approved service architecture, separate development/test scope |
| Workflows | Modernize | SharePoint 2013 workflows retired in Online April 2, 2026; test new Power Automate processes |
| SharePoint Add-Ins / ACS auth | Replace | Retired Online April 2, 2026; use supported extensibility and Entra auth |
| InfoPath/custom forms/BCS | Separate assessment | Replace dependencies and verify connector licensing |
| Search, service apps, timer jobs | Rebuild/reconfigure | No farm-wide lift-and-shift |
| Alerts, links, integrations | Inventory and remediate | Test subscriptions and embedded source URLs |
| Audit history / deleted content | Separate preservation decision | Do not assume ordinary content migration preserves compliance evidence |

Sources for product behavior: [S1, S5, S6, S9]. All “validate” actions above are
project recommendations. The package does not promise complete site fidelity.

Check service limits before choosing target structure: 250 GB individual file
upload, 400-character decoded path, 25 TB per site, and the 5,000-item list-view
threshold are different constraints. The threshold is not a 5,000-item list
capacity limit; indexed views and data design matter. Migration-tool or source
limits may be stricter than the cloud service limits. [S8]

Incremental copying is not bidirectional synchronization or a guaranteed deletion
mirror. Explicitly test source deletion, rename, folder move, permission changes
and target edits in the pilot. Maintain a change/deletion reconciliation register.
Throttling, many small files and unique permission scopes can reduce throughput;
adding workers is not a guarantee of proportional speed. Do not use Graph uploads
as a substitute for a migration engine when historical versions and permissions
must be preserved.

Native A→B SharePoint site moves have a different eligibility matrix and do not
merge into existing target sites. They do not imply the rest of a Team or Microsoft
365 group's workload has moved. Validate the current Microsoft FAQs and account
team-approved scope before selecting that route. [S10]
