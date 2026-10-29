# Identity, licensing and governance gate

Use Microsoft Graph to check **existing Entra identities** before SPMT migration, not to bulk-import SharePoint Server binary content.

## Permissions
- For read-only mapping checks: Graph delegated scopes \`User.Read.All\` and \`Group.Read.All\`, via consented Microsoft Graph PowerShell. Principle of least privilege; audit consent decisions.
- Users must already exist and be granted appropriate SharePoint Online service plans; a non-zero \`AssignedLicenses\` count does **not** confirm that SharePoint Online is enabled for that SKU. Examine \`licenseDetails.servicePlans\` or the Microsoft 365 admin center to confirm active SharePoint service plan.
- Verify license restrictions, guest access, Entra security groups vs Microsoft 365 Groups, synced/on-prem identities, inactive/deleted accounts, canonical UPNs and aliases. Never auto-provision missing users based only on the SPMT mapping file.
- SPMT user mapping format: three columns with no headers: source logon or SID (where supported), destination UPN, TRUE/FALSE IsGroup. SPMT cannot map AD group directly to destination SharePoint group and only migrates default SharePoint groups.
- Destination library permissions and unique role assignments require business-owner testing; overbroad security changes are go-live blockers.

## CMD operator example

\`\`\`cmd
rem Requires pwsh 7.4+ and Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups
rem Use actual securely stored user mapping, not example mapping
set "SPMT_USER_MAPPING=C:\secure\user-mapping.csv"
run.cmd identity-check
\`\`\`

The script exports output/identity-mapping-validation.csv (a private, gitignored folder). It checks whether listed users and groups resolve in the target tenant and flags license counts; it does **not** change accounts/groups/licensing or guarantee permission fidelity.

## Compliance gate
Inventory site permissions, retention labels, hold/eDiscovery requirements, audit, external sharing, allowed sync, sensitivity labels, residency and data loss prevention. Some features require separate Purview/Power Platform licensing. Document legal holds and closed business records before moving or deleting source content.

## Source of truth
- https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph?view=graph-powershell-1.0
- https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users/get-mguser?view=graph-powershell-1.0
- https://learn.microsoft.com/en-us/sharepointmigration/create-a-user-mapping-file-for-data-content-migration
