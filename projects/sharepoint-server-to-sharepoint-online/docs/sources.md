# Vendor sources (verified 2026-10-29)

Core migration
- SPMT and supported sources: https://learn.microsoft.com/en-us/sharepointmigration/introducing-the-sharepoint-migration-tool
- SPMT feature support: https://learn.microsoft.com/en-us/sharepointmigration/what-is-supported-spmt
- SPMT FAQ and unsupported master pages/InfoPath/forms: https://learn.microsoft.com/en-us/sharepointmigration/spmt-faqs
- SPMT settings: https://learn.microsoft.com/en-us/sharepointmigration/spmt-settings
- SPMT prerequisites / network endpoints: https://learn.microsoft.com/en-us/sharepointmigration/spmt-prerequisites
- SPMT PowerShell procedure: https://learn.microsoft.com/en-us/sharepointmigration/overview-spmt-ps-cmdlets
- Register-SPMTMigration parameters: https://learn.microsoft.com/en-us/powershell/module/microsoft.sharepoint.migrationtool.powershell/register-spmtmigration?view=spmt-ps
- Add-SPMTTask parameters: https://learn.microsoft.com/en-us/powershell/module/microsoft.sharepoint.migrationtool.powershell/add-spmttask?view=spmt-ps
- Incremental migration and task submission: https://learn.microsoft.com/en-us/sharepointmigration/spmt-create-task
- SPMT file size limits: https://learn.microsoft.com/en-us/sharepointmigration/mm-file-size-limitations
- SPMT user-mapping file, including no-header format and default SharePoint group limitation: https://learn.microsoft.com/en-us/sharepointmigration/create-a-user-mapping-file-for-data-content-migration
- SPMT workflow-to-Power Automate migration limitations: https://learn.microsoft.com/en-us/sharepointmigration/spmt-workflow-overview

Retirement and modernization
- SMAT retired 2026-10-01: https://learn.microsoft.com/en-us/sharepointmigration/overview-of-the-sharepoint-migration-assessment-tool
- Classic pages/publishing dates: https://learn.microsoft.com/en-us/sharepoint/classic-user-created-page-deprecation
- Modernization principles: https://learn.microsoft.com/en-us/sharepoint/dev/transform/modernize-classic-sites

Destination and finance
- SPO site creation: https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/new-sposite?view=sharepoint-ps
- SharePoint Online service limits: https://learn.microsoft.com/en-us/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-limits
- Microsoft 365 Canadian business pricing: https://www.microsoft.com/en-ca/microsoft-365/business/with-teams-plans-and-pricing

**Versioning caveat:** Microsoft updates documentation, API authentication and SKU prices. Reconfirm all URLs, SPMT module help (Get-Help), destination policy and licensing at implementation time. Source support claims here are explicitly from publicly documented Microsoft SPMT sources, not tested against a live farm.

Microsoft Graph / identity
- Graph delegated authentication: https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph?view=graph-powershell-1.0
- Get-MgUser: https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users/get-mguser?view=graph-powershell-1.0
- SPMT user/group mapping: https://learn.microsoft.com/en-us/sharepointmigration/create-a-user-mapping-file-for-data-content-migration
