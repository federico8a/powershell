# Timeline, downtime and cutover

These are project-planning ranges, not Microsoft SLAs. A representative simple
estate may fit 4–8 weeks; substantial custom applications, multiple tenants or
compliance remediation can take 8–16+ weeks. Inventory and pilot decide the plan.

| Phase | Illustrative elapsed duration | Exit evidence |
|---|---|---|
| Discover and classify | 3–5 business days | Inventory, exclusions, owners |
| Design and remediate | 5–10 business days | Identity map, capacity, resolved blockers |
| Pilot | 3–5 business days | Accepted fidelity, measured rates, recovery test |
| Seed and repeat waves | 3–15+ business days | Complete reports; bounded final delta |
| Final cutover | Reserve 4–8 hours per planned wave initially | Source frozen; delta validated; target released |
| Hypercare | 3–5 business days | Stable support and approved acceptance |
| Retirement | After agreed retention period | Recovery and compliance approval |

Seed copy normally allows source work to continue. Downtime is chiefly a write
freeze for the affected scope; source reads can remain available if the selected
lock mode permits. Start with a 4–8 hour reservation only as a planning assumption;
increase it when delta size, slow libraries or validation demand it. Never promise
zero downtime. Search and client synchronization may finish after content release.

## Before the window

T−10 days: accept pilot, publish new URLs and user guidance; agree the abort point.
T−5 days: complete seed; remediate all failures; verify group memberships and storage.
T−1 day: rerun incremental task with unchanged mapping/settings; record outstanding
delta and failures; test source restore; confirm service desk and business owners.
Do not allow uncontrolled target edits during seed/delta waves.

## Window sequence

1. Open change record; confirm tenant/URLs, scope and responsible approvers.
2. Freeze source writes for the wave using an administrator-reviewed site lock or
   equivalent access control. Stop integrations and jobs writing into that scope.
   Record previous lock settings. The included scripts do not lock sites for you.
3. Check final source counts and pending uploads. Rerun the same saved SPMT tasks
   with the same destinations/settings; capture the final delta report.
4. Reconcile failures/skips and expected filters. Test content, metadata, versions,
   permissions and critical business journeys with ordinary user accounts.
5. Go/no-go before the reserved recovery boundary: any unexplained data loss or
   permission exposure is no-go. Keep source authoritative and target unavailable.
6. Release target writes; update navigation/bookmarks/application links and user
   communications. Keep source read-only with an obvious new-location notice.
7. Monitor support, storage, search and automation. Capture owner sign-off by wave.

## Recovery and retirement

Before target release: stop migration, retain reports, leave destination isolated,
restore previous source access and rerun only after root-cause remediation.
After target release: do not blindly overwrite it with the source. Freeze affected
data, export destination-only changes and reconcile before any failback. Reopening
old URLs does not bring new cloud edits back on-premises. Test this recovery process
in the pilot and agree the maximum tolerable reconciliation period.

Keep source, backups and logs for the approved period (example 30–90 days, not a
mandatory rule). Prove restores, legal retention and operational handover before
removing farm services, accounts, certificates, databases or associated contracts.
