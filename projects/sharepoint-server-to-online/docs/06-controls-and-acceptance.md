# Delivery controls and acceptance

This is an implementation starter and operational runbook, dated 2026-11-09.
It is not a tenant-specific design or a guarantee that every feature migrates.
No customer systems were accessed. Source versions, users, volume, geography,
compliance constraints and available bandwidth must be collected before execution.

## Responsibilities and decision gates

| Role | Accountable activity | Evidence |
|---|---|---|
| Business owner | Scope, allowed outage, exclusions, acceptance | Signed scope and sample results |
| Migration lead | Waves, reconciliation, change record | Manifest, reports, issue register |
| Identity administrator | Matching, domain ownership, authentication | Mapping and sign-in tests |
| Workload administrator | Endpoint, permissions, migration execution | Configuration exports and job results |
| Security/compliance owner | Retention, holds, privileges, residency | Written disposition for protected content |
| Service desk | User instructions, client remediation | Support roster and known issues |

Gate 1: approved inventory and destination. Gate 2: representative pilot accepted.
Gate 3: capacity, recovery and cutover readiness. Gate 4: final reconciliation and
business sign-off. Gate 5: decommission after retention and recovery requirements.
An open data-loss, identity, unauthorized-access or mail-routing defect blocks go-live.

## Security and recovery

Use time-limited least privilege, MFA-compatible authentication and separate source
and destination sessions. Do not store credentials in CSV/JSON, transcripts or Git.
Use an encrypted restricted workstation; exported inventories contain personal data.
Keep recovery copies outside the migration job and prove a representative restore.
Preserve legal holds: migration tooling is not authority to release a hold.
Check residency, contractual data handling and external sharing before any staging.
Keep logs in a protected operational location; only sanitized examples belong in Git.

Choose target RPO/RTO with the owner. Before finalization, source remains authoritative.
After destination writes begin, simply reopening the source creates divergent data;
freeze both sides, reconcile changes and execute a separately approved recovery plan.
A migration report is evidence of processing, not proof of complete business fidelity.

## Evidence templates

Maintain a row for every scope unit: source, destination, wave, owner, source count,
target count, expected difference, error/skipped count, retry action, sign-off time.
Record every exclusion with reason and owner acceptance. Store before/after exports,
job IDs, settings, tool versions, screenshots of user tests and restore evidence.

## Validation status

The offline Python planner is tested locally, including invalid input and arithmetic.
PowerShell scripts are implementation starters reviewed against Microsoft cmdlet
documentation. PowerShell and the Microsoft workload modules are not installed in
the build environment; syntax execution, authentication and live migration tests
remain required on the intended Windows/Exchange hosts. No claim of 100% production
compatibility is made. See VALIDATION.md for the actual test results and release gates.
