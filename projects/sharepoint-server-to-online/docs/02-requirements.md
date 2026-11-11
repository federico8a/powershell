# Requirements and discovery

## Inventory required before sizing

Collect farm version/build, web applications, authentication providers, site
collections/subsites, owners, databases, logical content bytes, version bytes,
file and list-item counts, largest files, growth per day and business criticality.
Inventory templates, content types, fields, term groups, workflows, InfoPath/forms,
WSP solutions, custom web parts, event receivers, BCS integrations, search, links,
alerts, scheduled jobs, service accounts and retention requirements.

The included inventory script exports a starting list of sites, webs and lists.
It does not enumerate every file, permission or application. Run SPMT scanning
and a separate customization/permissions review to complete discovery.

## Infrastructure and access

| Area | Requirement / preflight evidence |
|---|---|
| Source | Reachable SharePoint URL; supported source/authentication combination; readable content and version history |
| Migration host | Dedicated Windows machine matching current SPMT prerequisites; supported PowerShell/.NET; enough staging disk for pilot peak plus headroom |
| Network | HTTPS access to Microsoft authentication, SharePoint and documented migration/storage endpoints; proxy compatibility; measured throughput |
| Destination | Approved tenant geography; licensed users; site URLs and owners; enough pooled storage and per-site quota |
| Permissions | Source access sufficient for selected content; destination site collection administrator or appropriate SharePoint administration role; additional privilege for global taxonomy operations |
| Identities | Every retained author and access principal mapped or explicitly dispositioned; unresolved identities block sensitive content waves |
| Governance | External sharing, sensitivity labels, retention and DLP design, version policy and backup/restore agreed |
| Business | Named owners, write-freeze approval, communications, validation sample and support staff |

SPMT's current supported-source table lists SharePoint Server 2010/2013/2016/2019.
Do not infer Subscription Edition or older versions are supported from this list;
check the installed release and obtain a validated path for an unlisted source.
Tool acceptance of an old farm is not a supported-lifecycle statement. [S1–S3]

Use existing source backups and test recovery. Check out or check in documents
according to a documented business decision; do not discard unpublished work.
Create the approved destination site structure before the pilot where required.
Test term/content-type dependencies before migrating dependent libraries. If using
new Entra groups, establish their membership first; a matching display name is
not sufficient evidence of identity equivalence.

## Pilot selection and pass criteria

Include large and small files, multiple versions, unique permissions, external
users, non-ASCII names, long paths, metadata lookups, representative pages and a
critical business process. Verify read AND denied access, author/editor mapping,
timestamps, required metadata, versions, links and application behavior. Record
effective GiB/hour and items/hour; small items can dominate despite low data size.
Accept zero unexplained missing items and zero unauthorized permission expansion.
