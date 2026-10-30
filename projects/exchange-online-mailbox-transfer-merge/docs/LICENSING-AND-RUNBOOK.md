# Mailbox transfer/merge: licensing, change plan and rollback (2026-10-29)

## Licensing
| Operation | Assignment level | Notes |
|---|---|---|
| Delegate A to B | Existing Exchange licenses **per user** | No extra native migration license; FullAccess and SendAs separate. |
| Convert A to shared | Usually no additional shared license <=50 GB absent archive/hold | A shared mailbox exceeding 50 GB, with archive, or on litigation hold needs appropriate Exchange Online Plan 2/equivalent. B remains licensed; retain backing Entra account. |
| Soft-deleted/inactive A to B restore | B must have valid **per-user** Exchange license and space | No standalone tenant migration product license for native restore request. Source must be recoverable; retention expiry may prevent it. |
| Active A to B PST merge | Existing mailbox licenses; desktop Outlook or supported Purview import | PST import is copy, not native live mailbox ownership reassignment. |
| Graph PST export as intermediate | E3/E5 exporter per-user; for E3 API, tenant-level Azure/Purview PAYG billing | May incur metered export GB costs, verify budget before API export. |
| PST network import | Target Exchange mailbox license; Import permission | Uses supported wizard-provided AzCopy, no separate Azure subscription merely to import PST. <=20 GB PST recommended; max 500 mapping rows/job. |

## Source-to-target runbook
1. Authorize data access and preserve audit, legal hold and privacy requirements.
2. Assess source/target: SMTP, ExchangeGuid, type, item count, size, archive, quota, delegated access, retention and licensing.
3. Choose exactly one:
   - **Access:** Delegate FullAccess; authorize SendAs separately. No copy.
   - **Former employee:** Convert A to shared; assign delegation; block sign-in separately. Keep backing account.
   - **Inactive/soft-deleted merge:** `New-MailboxRestoreRequest` into dedicated B target root. No active-to-active usage.
   - **Active-to-active:** export A's PST, then import through classic Outlook or Purview network import.
4. Validate Inbox/Sent/Calendar/contacts/attachments/duplicates, quota, mail flow, messages arriving during copy, and source archive.
5. Keep source until formal acceptance; a one-time PST does **not** include mail arriving after export. Plan mail-flow/delta handling.
6. No DNS/MX changes or typical mailbox downtime for a same-tenant handover; asynchronous requests have variable completion times.

## Rollback and traps
- Delegation: remove **only the newly added permissions**, preserving previous ACLs.
- Shared conversion: convert back to Regular only with proper license/user identity and approval.
- Restore/PST merge: no guaranteed transaction rollback; dedicated root folder improves segregation but deleting items can violate hold. Prefer source preservation and documented recovery strategy.
- Rules, send-as rights, meeting ownership, Teams/OneDrive, signatures, client settings and mobile connections are **not** a complete mailbox migration by themselves.
- Hybrid-synced source objects need supported on-premises Exchange management; do not assume cloud-only GUI is authoritative.

Microsoft: https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-permissions-for-recipients ; https://learn.microsoft.com/en-us/microsoft-365/admin/email/remove-license-from-shared-mailbox ; https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/new-mailboxrestorerequest ; https://learn.microsoft.com/en-us/microsoft-365/compliance/use-network-upload-to-import-pst-files