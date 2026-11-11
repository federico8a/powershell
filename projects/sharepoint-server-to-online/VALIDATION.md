# Validation and release gates

Build date: 2026-11-09.

## Completed locally

- Offline Python cost/time calculator: four unittest methods, including nine invalid
  value subcases, cost arithmetic, transfer arithmetic, zero scope and missing fields.
- Python compilation, example calculation, Markdown local-link and ZIP integrity checks.
- PowerShell code review: Plan defaults, explicit write modes, target scope checks,
  no hard-coded secrets, no automatic cutover/DNS/source-deletion operations.

## Not executed here

- PowerShell parser/runtime (pwsh unavailable), Microsoft modules and PSScriptAnalyzer.
- Actual source inventory export, tenant authentication, endpoints and MFA compatibility.
- SPMT scan, file/version/permission fidelity, hybrid moves and cross-tenant migration.
- Real throughput, live cutover, rollback and restore tests.

## Required before a production release

On the intended Windows hosts, parse all PowerShell scripts with
`[System.Management.Automation.Language.Parser]::ParseFile` and fix every error;
run PSScriptAnalyzer and review findings. Test offline Plan mode with valid and
malformed CSVs, empty CSVs, duplicate entries and wrong destination scope. Confirm
`-WhatIf` causes no migration/batch creation. Verify inventory access and output.

Use an isolated pilot with real workload modules and approved nonproduction data.
Exercise normal flow, authentication denial, missing permissions, interrupted jobs,
duplicates, pre-existing destination content/recipients, throttling and rollback.
Record tool versions, input manifest hashes and expected/actual results. Business
owners must accept content and functionality before any production wave. A passing
local calculator test is not a passing migration acceptance test.
