# Licensing and costs — CAD, 2026-11-09

| Component | Charging unit | Requirement / cost treatment |
|---|---|---|
| SharePoint Online entitlement | Per internal user | SharePoint plan or a qualifying Microsoft 365/Office 365 suite; not one admin license for an entire company |
| Business Basic, no Teams | Per user/month, paid yearly | Public Canadian page: CAD $7.30; includes SharePoint and Exchange; verify exact SKU at purchase |
| Business Basic, with Teams | Per user/month, paid yearly | CAD $9.50 on reviewed page; maximum 300 users for Business plans |
| Standalone SharePoint plan | Per user | Obtain current Canadian quote; not independently price-verified in this package |
| SPMT | Tool | Free Microsoft tool; implementation time and infrastructure remain costs |
| SharePoint storage expansion | Capacity per tenant | Quote extra storage after counting versions, retained content and growth |
| Power Automate / Power Apps | Per user or process/capacity, by SKU | Premium connectors and rebuilt applications can require additional licensing |
| Entra / Purview / security | Usually per covered user or capacity | Select based on actual Conditional Access, compliance and governance features |
| On-premises overlap | Server/CAL/SQL/Windows/hosting as applicable | Retain valid rights until retired; cloud licenses do not automatically erase every source cost |
| Third-party migration | Vendor-specific | Quote user/data/site/operator/duration metric and support |
| Native A → B SharePoint migration | Per 100 GB moved | Cross-Tenant Shared Data Migration; currently EA eligibility; separate from mailbox per-user add-on |
| Backup and recovery | Vendor user/capacity/tenant metric | Add recurring quote; retention alone is not your full recovery design |

Sources: [S4, S7, S8, S10]. Prices are before tax, annual-commitment monthly
equivalents, not guaranteed month-to-month offers. Existing suite entitlement can
reduce incremental license spend to zero. Guest access has separate service terms;
do not count all guests as employees or assume all guest capabilities are free.

At the observed no-Teams Basic price: 25 users = $182.50/month ($2,190/year),
100 = $730/month ($8,760/year), 300 = $2,190/month ($26,280/year). These are
license-only totals. If Exchange uses the same suite, do not count another suite.

Common qualifying plans provide a shared pool of 1 TB plus 10 GB per purchased
license; plan exceptions exist. This is separate from each user's OneDrive space.
Measure actual tenant available capacity; source database size is not target
storage consumption. Budget versions, preservation/retention copies, recycle bin,
growth and temporary duplicate content. [S8]

Implementation estimate formula: discovery + cleanup + target design + identity
mapping + pilot + wave operations + modernization + support, multiplied by the
agreed hourly rates. Add overlap, storage, tools, backup and contingency. No fixed
project quote is credible without inventory. `tools/planner.py` provides editable
assumptions and separates annual recurring cost from transition costs.
