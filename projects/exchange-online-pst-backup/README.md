# Exchange Online PST Backup

Research snapshot: October 29, 2026. Microsoft-supported procedures; not live-tenant tested.

**GUI:** Microsoft Purview > eDiscovery > Cases > Searches > create a search restricted to the intended Exchange Online mailbox; generate statistics, then Export > PST, separate sources, preserve folder paths, and download process reports and package within **14 days**. Alternatively, Outlook for Windows: new Outlook Settings > Files > Export, or classic Outlook File > Open & Export > Import/Export > Export to PST; classic must cache **All** messages. Do not export PST to a OneDrive-synced directory.

**PowerShell:** The documented Microsoft Graph v1.0 `POST /security/cases/ediscoveryCases/{caseId}/searches/{searchId}/exportResult` creates an export job after a case/search is configured. It does not instantly download a PST. Exchange Online does **not** support `New-MailboxExportRequest` (on-premises Exchange only).

**Licensing:** Exchange mailbox appropriately licensed per user; Purview eDiscovery export requires qualified E3/E5 exporter and case permission. E3 eDiscovery Graph API use requires Purview pay-as-you-go with tenant Azure subscription and may entail export-volume billing. No mailbox mail-flow outage or MX cutover is expected, but a PST is a point-in-time copy, not a complete continuous backup.

**Validation:** inspect indexed/unindexed coverage, archive, errors, folder structure, item counts, attachments, encrypted messages, local SHA-256 and a test recovery before retiring anything.

Microsoft sources:
- https://learn.microsoft.com/en-us/purview/edisc-search-export
- https://learn.microsoft.com/en-us/graph/api/security-ediscoverysearch-exportresult?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/purview/edisc-billing
- https://support.microsoft.com/en-us/outlook/export-emails-contacts-and-calendar-items-to-outlook-using-a-pst-file
