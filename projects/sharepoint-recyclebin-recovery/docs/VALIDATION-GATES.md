# Validation gates — do not claim 100% compatibility without live-tenant execution

Test against an **isolated, approved SharePoint Online test site collection**, with an Entra interactive app, the required delegated SharePoint permissions, and a site collection admin. Use only disposable test documents. Do NOT point destructive test setup at production.

## Gate A — source / static (offline)

- [ ] PowerShell 7.4+ parser accepts all `.ps1`/`.psm1` files (no parser errors).
- [ ] `Invoke-Pester ./tests -Output Detailed -CI` passes, including no-match report, CSV formula safety, scope validation, second-stage enums and throttle classification.
- [ ] PnP.PowerShell stable loads and has `Get-PnPRecycleBinItem`, `Restore-PnPRecycleBinItem`, `Get-PnPAccessToken`, `Get-PnPFile` and `Get-PnPFolder` with documented parameters.
- [ ] Workstation policy allows interactive sign-in and the account is a site collection administrator; minimal approved Entra app consent verified.
- [ ] No credentials, access tokens, production reports, or personal data in Git commits.

## Gate B — nonproduction acceptance with real SharePoint

Perform in this order, capturing before/after screenshots, library counts, version histories, results JSON, and audit logs:

1. [ ] A first-stage deleted file under a document library is inventoried with correct URL/path/ID/deletion UTC/user.
2. [ ] A second-stage deleted file is likewise inventoried.
3. [ ] A deleted folder with two nested files is inventoried without falsely claiming recursive child totals.
4. [ ] A nested subfolder independently deleted is handled after a parent restore, without false positive `RestoreCommandSucceeded` for an absent ID.
5. [ ] A site URL, subsite URL, document-library URL, folder URL and individual file URL each select only expected scope.
6. [ ] `Forms/AllItems.aspx?id=...` URL selects the correct folder; a cross-collection `id=` is rejected.
7. [ ] A folder with a dot in its name works with explicit `-MatchMode Prefix`.
8. [ ] One-day inclusive/exclusive UTC dates match expected items at midnight and exclude neighboring days.
9. [ ] Email filter is case insensitive; short username behavior verified, including ambiguity warning.
10. [ ] No-match inventory is clean, creates reports, and does not offer restore operations.
11. [ ] A preview without `-Apply` cannot modify any SharePoint item.
12. [ ] An incorrect typed `RESTORE N` confirmation does not modify items.
13. [ ] Restore one file and one folder, then verify bytes, names, paths, permissions, versions and metadata.
14. [ ] Restore 25+ independent files with `-Workers 10`; confirm each ID is accounted for.
15. [ ] Simulate 429/503 with `Retry-After` in mocked unit cases and observe automatic reduction of concurrency when real 429/503 occurs.
16. [ ] Verify both default `Skip` and explicitly approved `AllowRename` against an existing destination path, documenting final filenames.
17. [ ] Interrupt execution mid-batch; resume with the same manifest; absent IDs are flagged rather than blindly retried.
18. [ ] Modify manifest path outside scope; `-ResumePath` must refuse to run.
19. [ ] Attempt access with non-admin identity; enumeration must fail closed.
20. [ ] Attempt restoring a file after deleting its parent library; capture documented manual recovery path rather than creating library automatically.
21. [ ] Confirm no token values appear in console transcript, CSV, JSON, repo history, or logs.
22. [ ] Run a time-consuming test to expose access-token expiry; confirm it fails safely and an operator can resume.
23. [ ] Verify `results.json`/CSV are consistent; no duplicate or lost IDs after restart.
24. [ ] For folders containing deleted descendants not listed individually, compare actual contents after restore against source test manifest.
25. [ ] Verify that downstream users can access the recovered files after version/permission reconciliation.

## Gate C — operational qualification

- [ ] SharePoint Online commercial/geo host confirmed; sovereign variants are not automatically supported.
- [ ] Approved incident/change record, owner signoff, business impact, audit retention and report permissions completed.
- [ ] Check folder/library/site existence before choosing this tool; bin restore is **not** tenant-wide backup/point-in-time restore.
- [ ] For large bins, `-RowLimit` is above both stage counts, and repeated snapshots do not hit the cap.
- [ ] For 10 workers, monitor throttle and token life; start with 2–4 workers in high-load production tenants.
- [ ] Verify final live content using independent item counts, versions, permissions, hashes where relevant, and owner validation.

### Stop conditions

Stop on incomplete bin enumeration, bad manifest, insufficient permissions, ambiguous collision, expired/invalid tokens, transient errors not classified as throttling, or a failed live-tenant gate. These are **manual-review** conditions; do not mark files as successfully restored just because a server response is ambiguous.

**Interpretation of status:** `RestoreCommandSucceeded` means PnP returned without error for that ID. It does *not* prove the original content, versions, metadata or permissions were recovered as expected. Only an independent post-restore verification can close the incident.
