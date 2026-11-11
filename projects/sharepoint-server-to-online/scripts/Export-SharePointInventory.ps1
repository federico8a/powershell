# Run in the on-premises SharePoint Management Shell. Read-only source operations.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not (Get-Command Get-SPSite -ErrorAction SilentlyContinue)) {
    throw 'Run from SharePoint Management Shell with authorized farm access.'
}
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new output directory.' }
$null = New-Item -ItemType Directory -Path $OutputDirectory
$rows = [System.Collections.Generic.List[object]]::new()
foreach ($site in Get-SPSite -Limit All) {
    try {
        foreach ($web in $site.AllWebs) {
            try {
                foreach ($list in $web.Lists) {
                    $rows.Add([pscustomobject]@{
                        SiteUrl=$site.Url; WebUrl=$web.Url; WebTemplate=$web.WebTemplate
                        ListTitle=$list.Title; ListId=$list.ID; BaseTemplate=$list.BaseTemplate
                        ItemCount=$list.ItemCount; Hidden=$list.Hidden
                        UniquePermissions=$list.HasUniqueRoleAssignments
                        Versioning=$list.EnableVersioning
                        SiteStorageBytes=$site.Usage.Storage
                    })
                }
            } finally { $web.Dispose() }
        }
    } finally { $site.Dispose() }
}
$rows | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'lists.csv') -NoTypeInformation -Encoding UTF8
Write-Output 'Inventory complete. SiteStorageBytes repeats per list; do not sum it across rows.'
