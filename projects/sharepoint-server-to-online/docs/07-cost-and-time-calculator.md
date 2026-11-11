# Offline calculator

Run `python tools/planner.py config/budget.example.json` from the project root.
Run tests with `python -m unittest discover -s tools -v`.
Python 3.10+ recommended; standard library only. It never connects to Microsoft.

Edit the JSON with approved quotes and pilot measurements. Data is in GiB, rates
in GiB/hour; costs are CAD before tax. Include versions/archives in scoped data.
`measured_gib_per_hour` means effective aggregate completed throughput, not link
speed or per-worker speed. Do not multiply it by a worker count.

Initial transfer = data / measured rate × transfer factor. Final delta uses the
same formula. Reserved cutover adds validation time; it is not measured downtime.
For email, lock/reconnection time can be shorter than the reserved window. For
SharePoint, the write freeze normally spans the last delta and validation.

Target recurring = users × monthly license price + other recurring charges.
Transition = (labor + one-time tools + old-platform monthly cost × overlap months)
× (1 + contingency). Year one = 12 × target recurring + transition. Target license
spend starts at project start in this model. Upfront annual billing is a cash-flow
issue not represented by the monthly equivalent. Already-paid licensing can make
incremental spend lower; contractual overlap can make it higher.

The sample uses hypothetical 80 hours at $100/hour, $1,000 tools, two months of
$500 old-platform costs and 20% contingency: transition budget $12,000. These
are planning inputs, not vendor quotes. Enter cross-tenant add-ons and backup,
storage, certificates, consultant travel and modernization charges explicitly.
For a combined SharePoint + Exchange rollout using one suite, count the suite
once per user: do not add both projects' recurring totals.

With 1,000 GiB, 20 GiB/hour and factor 1.3, seed transfer is 65 hours. A 25 GiB
final delta is 1.625 hours; two validation hours produce a 3.625-hour reserved
window (displayed to two decimals). For 500 GiB at 10 GiB/hour it is also 65 hours.
At 5,000 GiB and 40 GiB/hour it is 162.5 hours. These examples do not predict
elapsed project duration; discovery, remediation and sign-off usually dominate.
