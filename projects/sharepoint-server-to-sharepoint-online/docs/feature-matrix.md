# Full farm feature disposition matrix

**Required outcome = 100% of inventory objects assigned a destination or signed exclusion/remediation; NOT 100% binary/configuration parity.** Export inventory, assess, then record explicit owner acceptance per exception. A successful SPMT job does not guarantee custom solution parity.

| Object / configuration | Default route | Validation and caveat |
|---|---|---|
| Site collections and supported out-of-box subsites | SPMT site migration | Classic hierarchy vs modern flat/hub structure must be chosen explicitly. |
| Libraries, documents, folders, list items, attachments | SPMT | Count, bytes, attachments, permissions, links and samples; investigate failed and skipped objects. |
| Versions, created/modified authors/dates | SPMT conditional | Configure all versions, validate author mapping and sample version trees. Retention/versions can expand costs. |
| Site columns/content types | SPMT conditional | Enable all site fields/content types; check lookup/reference behavior and hidden fields. |
| Managed metadata, term store | SPMT conditional | Term-group migration is explicitly off in automation (Microsoft SPMT defaults ON), and requires separate taxonomy-owner/admin approval, tenant privileges and validation before enabling. |
| Standard site navigation/logo/title/features | SPMT supported settings | Preserve all settings, verify names, URLs, features and links. |
| Standard SharePoint web parts and pages | SPMT supported subset | Inventory page layouts and web part types; classic-modern conversion is separately planned. |
| SharePoint unique permissions and inheritance | SPMT conditional | Preserve permissions; build user identity mapping before bulk; test item-level access. |
| Default SharePoint groups | SPMT conditional | SPMT migrates default groups; custom group-to-group mapping and AD-to-SharePoint group mapping are NOT provided as equivalent. |
| SharePoint audiences / audience-targeted lists | Conditional/loss risk | Selecting migration can lose audience-targeting configuration; test and rebuild targeting. |
| SharePoint Designer 2010/2013 workflows | SPMT workflow-to-Power Automate conditional | Definition/association may migrate; history does not; unsupported actions require redevelopment. |
| SharePoint 2010 built-in workflows | SPMT supported subset | Approval/feedback/signature/three-state; individually test new flow behavior. |
| SharePoint site workflows, custom WF activity, Nintex/K2 | Rebuild/vendor migration | SPMT workflow support excludes site workflows and runtime/history; license Power Platform/vendor as needed. |
| InfoPath forms and customized New/Edit/View forms | Rebuild | SPMT does not migrate these forms intact. Consider Power Apps/SharePoint lists. |
| Custom master pages, page layouts, publishing, branding | Rebuild/modernize | Master pages unsupported; classic publishing risks and 2027+ restrictions. |
| Farm solutions (WSP), full-trust code, event receivers, timer jobs | Re-architect | Do not copy server-side binaries into SaaS. Consider SPFx, Azure Functions/Logic Apps/Power Automate. |
| Search service app, search scopes/crawl rules, managed properties | Reconfigure | SharePoint Online search is service-managed; audit and recreate equivalent search config where supported. |
| External data/BCS, Secure Store, SQL connected web parts | Re-architect | Network/gateway/credentials and vendor prerequisites; no automatic migration. |
| Custom site templates, unsupported list templates | Conditional/rebuild | Evaluate SPMT list/site template support individually; do not assume. |
| Alerts, subscriptions, My Sites, profile service, social/community | Remediate | Legacy features do not have guaranteed same behavior. |
| Integrations (SSRS, Power BI, ERP, REST, webhooks, hard-coded URLs) | Reconfigure | Change endpoint, auth, least privilege and functional regression tests. |
| Record center, eDiscovery, labels, retention and audit | Governance redesign | Purview licensing and compliance/legal review; do not assume settings follow content. |
| Recycle bins, deleted content, workflow histories | Backup/archive/manual exception | Do not promise comprehensive restoration; inventory and document retention needs. |
| Tenant sharing, default access, external guest access, conditional access | Target tenant policy | Approved before cutover and tested after; avoid accidental exposure. |
| Page links, images, embedded references, web part data sources | Link remediation | Scan old domain URLs and embedded references, update with content owner sign-off. |
| User profiles, photos, AD synchronization, authentication providers | Entra/identity project | This is not a domain controller/auth provider lift and shift. |
| Farm admin settings, service applications, search index, topology | Retire/rebuild | No farm-level equivalence in SharePoint Online. |

## Migration tool decision
1. **First choice**: Microsoft SPMT, with supported site setting and workflow options configured and pilot-tested.
2. **Next choice**: PnP/SPO PowerShell for modern site provisioning, settings and structured rebuild; Microsoft Graph for Entra and supported cloud API operations, not direct source content migration.
3. **Commercial**: licensed ShareGate/AvePoint/Quest or vendor-specific export/import if pilot shows native gaps. Require a features POC and signed cost estimate. Tools may still NOT migrate full-trust customizations.
4. **Last resort**: archive content with full provenance, rebuild from requirements or retain read-only on-prem archive with security/retention approval.

## Microsoft limitations to flag
- SPMT cannot perform structure-only site migration or set an arbitrary modern target template.
- Master pages, InfoPath and custom New/Edit/View forms are not migrated.
- Microsoft says custom SharePoint group mapping is limited; test default and custom groups thoroughly.
- Workflow history is not included in supported workflow-to-Power Automate conversion. Conversion needs Power Platform Administrator, Environment Maker access, designated flow owner, activation and end-to-end tests.
- Legacy classic publishing and user-created classic page roadmap requires early modernization planning.
- Former SMAT scanner retired on **2026-10-01**; use **SPMT scan**. See docs/sources.md.
