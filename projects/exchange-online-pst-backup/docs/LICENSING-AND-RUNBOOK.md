# PST export: licensing, runbook and caveats (2026-10-29)

## Assignment and costs
| Requirement | Assignment level | Notes |
|---|---|---|
| Existing Exchange Online mailbox | Per user/mailbox | Keep source licensed/active throughout export and verification. |
| Purview GUI eDiscovery export | Qualifying E3/E5 license per exporting user; Purview eDiscovery Manager/Administrator and case membership | Microsoft documentation explicitly identifies enterprise E3/E5 for exporter. Verify alternatives with your licensing team. |
| Graph v1.0 eDiscovery API | Delegated Graph permission and consent plus a Purview role; for E3-level tenants, **tenant Azure subscription/Purview pay-as-you-go** required | Export GB may be billable. Microsoft's $10/GB illustration is hypothetical, not published contract pricing. |
| Outlook desktop PST | Per desktop-app user entitlement | For new Outlook, Settings > Files > Export. Classic Outlook required for bulk PST import to a mailbox. |
| Secure local disk | Customer storage | Capacity, encryption, access control and storage lifecycle may add costs. |

## Production change workflow
1. Confirm purpose/approval, legal holds, retention, privacy controls and source ExchangeGuid.
2. Record archive status, mailbox size, user licensing, operator eDiscovery role, Graph consent and approved PAYG budget.
3. Create a case and **exact-scoped mailbox search** in https://purview.microsoft.com. Run statistics; review dates, search query, hits, archive and partially indexed data.
4. Start export from GUI or Graph API (HTTP 202 means queued, **not completed**). Preserve folder paths and request processing report.
5. Download every package by the **14-day expiry**, then verify process report exceptions, PST files, item counts, Inbox, Sent, Calendar, contacts, archive and attachments.
6. Create SHA-256 manifest and test recovery; store PST encrypted with restricted access. Remove copies only under approved retention.
7. Keep source operational throughout validation; no MX/DNS cutover and normally no mailbox outage.

## Failures
- 403: investigate eDiscovery role, case membership, Graph admin consent, user license, E3 PAYG activation.
- Missing content: investigate query, targeted data source, archive, index lag, DLP/restricted content and unsearchable/partially indexed items.
- Large export: split/organize PSTs via Purview and account for bandwidth and disk.
- Rollback: export is read-only; safely dispose of local copies only if no hold or preservation requirement applies.

Microsoft: https://learn.microsoft.com/en-us/purview/edisc-search-export ; https://learn.microsoft.com/en-us/purview/edisc-billing