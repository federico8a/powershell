# Exchange Online — Mailbox Transfer, Access and Merge

Microsoft-source runbook, research snapshot October 29, 2026. **No live-tenant testing.** PowerShell 7.2+.

## Decision tree

| Intent | Supported method |
| --- | --- |
| Give B access to A's historical mail | Exchange admin center mailbox delegation: FullAccess; optional SendAs |
| Departing employee | Convert A to **shared** in Exchange admin center, assign B FullAccess and optionally SendAs, block former account sign-in but **do not delete** the backing Entra account |
| Copy A into B where A is already soft-deleted or inactive | Exchange Online PowerShell `New-MailboxRestoreRequest -SourceMailbox <GUID> -TargetMailbox <GUID> -AllowLegacyDNMismatch -TargetRootFolder ImportedFromOldUser` |
| Both source A and target B are **active** | Export source PST, then classic Outlook import into B, or Purview Data Lifecycle Management > Microsoft 365 > Import with supported AzCopy and mapping CSV |
| Future messages only | Admin center Mail > Forwarding (does not copy historical mail) |

**No general-purpose one-command active mailbox ownership transfer or active-to-active merge is available.** Renaming/reusing a former employee's Entra login is not an appropriate mailbox move and can affect auditing, OneDrive, Teams, MFA, licenses and legal attribution.

## PowerShell

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
./main.ps1 -Action Inspect -SourceMailbox old@contoso.com -TargetMailbox new@contoso.com
./main.ps1 -Action Delegate -SourceMailbox old@contoso.com -TargetMailbox new@contoso.com -GrantSendAs -Execute
./main.ps1 -Action ConvertShared -SourceMailbox old@contoso.com -Execute
# ONLY when A is already soft-deleted/inactive. NEVER delete an active source to make it available:
./main.ps1 -Action MergeDeleted -SourceExchangeGuid '11111111-1111-1111-1111-111111111111' -TargetMailbox new@contoso.com -Execute
./main.ps1 -Action GenerateImportMap -PstPath 'C:\Secure\old.pst' -TargetMailbox new@contoso.com -CsvPath 'C:\Secure\mapping.csv'
```

## GUI

**Shared handover:** https://admin.exchange.microsoft.com > Recipients > Mailboxes > select A > More actions > Convert to shared. Then Mailbox delegation > Read and manage (Full Access) > add B; optionally separately Send As. Verify B's Outlook access and shared mailbox sign-in restrictions.

**Active-to-active PST:** export A (see companion project), then classic Outlook > File > Open & Export > Import/Export > Import from another program or file > PST, choose target B. New Outlook cannot yet bulk-import PST into a mailbox.

**Large import:** https://purview.microsoft.com > Data lifecycle management > Microsoft 365 > Import; upload PST via the supported **AzCopy version downloaded from Purview wizard**, submit generated mapping CSV and review job. Microsoft recommends PST files <=20 GB, max 500 CSV mapping rows per job. Mapping CSV alone does not import anything.

## License, risk and downtime

- B's own Exchange account is licensed **per user**. Delegation has no extra per-tenant Exchange migration license. Shared mailbox **<=50 GB** usually needs no license unless online archive/litigation hold; larger/archived/held mailbox needs qualifying Plan 2 licensing. Do not remove A's license automatically before checking.
- Purview eDiscovery PST export has separate licensing; E3 Graph API export can require **tenant-level Purview PAYG** and billable export GB. Network PST import does not need a separate Azure subscription.
- No MX/DNS changes and generally no mail outage for these same-tenant flows. Restore jobs and imports are asynchronous/variable duration; missing mail can result if emails arrive after the source PST snapshot.
- Confirm holds, retention, target capacity, archive, migration permissions, duplicates, item counts, calendar, contacts, rules, forwarding and privacy before decommissioning. **No guaranteed atomic rollback for data merges.** Keep source until validation and approval.

## Microsoft documentation
- https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-permissions-for-recipients
- https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-user-mailboxes/convert-a-mailbox
- https://learn.microsoft.com/en-us/microsoft-365/admin/add-users/remove-former-employee-step-4
- https://learn.microsoft.com/en-us/microsoft-365/admin/email/remove-license-from-shared-mailbox
- https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/delete-or-restore-mailboxes
- https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/new-mailboxrestorerequest
- https://learn.microsoft.com/en-us/microsoft-365/compliance/use-network-upload-to-import-pst-files
