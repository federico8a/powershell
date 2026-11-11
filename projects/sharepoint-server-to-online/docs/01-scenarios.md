# Choose the migration scenario

An on-premises farm is not itself a Microsoft 365 tenant. “Same tenant” below
means the organization's current Microsoft 365 tenant and identity relationship.

| Scenario | Data path | Identity approach | Tool / extra work |
|---|---|---|---|
| Existing tenant A | Farm → A | Existing users; validate mapping | SPMT baseline |
| New tenant B, data still on-premises | Farm → B | Provision/map users and groups in B | SPMT directly to B; no intermediate A required |
| Farm hybrid-connected to A, destination B | Farm → B | Explicit B mapping; review all A integrations | SPMT content; redesign hybrid search, navigation, sign-in and app registrations |
| Content already in tenant A | A → B | Cross-tenant identity mapping | Separate native cross-tenant feature if eligible, or evaluated third-party tool |
| Merge into existing populated sites | Farm → existing site | Collision and ownership review | Pilot exact list/content-type conflicts; no promise of safe automatic merge |

SPMT is an on-premises ingestion tool, not the tenant-to-tenant engine. For native
SharePoint cloud-to-cloud moves, current Microsoft guidance describes Enterprise
Agreement eligibility and capacity licensing in 100-GB units. Native moves are
one-time moves without incremental passes. Do not reuse the seed/delta runbook for
that path. Confirm feature availability, site eligibility, size/item limits,
target URL availability and Customer Key restrictions with Microsoft. [S4, S10]

Before choosing tenant B, decide who owns the target identities, whether users
remain AD-synchronized, and which tenant retains the custom sign-in domain. Domain
association is tenant-specific; temporary B onmicrosoft.com identities may be
needed during transition. Mapping users does not transfer passwords, MFA methods,
devices, licenses, enterprise applications or Teams configuration. [S11]

Use native SPMT first for supported content. Evaluate a paid migration product
when transformation, complex mapping, unsupported source versions or reporting
needs exceed it. Require a trial with representative content and a written
coverage matrix; a commercial tool still cannot recreate unsupported farm code
inside SharePoint Online. Obtain a vendor quote specifying users, data, sites,
operator seats, subscription duration and rerun rights.
