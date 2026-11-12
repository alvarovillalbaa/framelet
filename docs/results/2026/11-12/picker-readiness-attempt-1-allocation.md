# Picker readiness attempt 1 — no executor

12 November 2026. [Run 43211146295](https://github.com/alvarovillalbaa/framelet/actions/runs/43211146295)
attempt 1 ended at 11:55:23 UTC with workflow failure and job 131158773329
cancelled. The job reports runner ID zero and no steps, after queuing from
11:40:20 UTC. [Original connected-tool metadata](picker-readiness-attempt-1-allocation.json)
is preserved before any diagnostic or new candidate activation.

Source `97036fc9864dafe183d3d2500a919512d08678df`, exact tree
`c4abd4253784d6c71ba70fade2f1aa2c6a97368f`, native source
`6495e832414b99caf36c9e97c02c98daa2f17c5e`; QA
`28ac1d1bd33ec7f1e23038cd17c1d276523ff4ce`.
No checkout, compilation, app/fixture/test, picker, prompt, capture or executor
resource setup ran. There is no native assertion result or PNG/AX evidence.
The source-review postcheck/selector corrections were not executed either.
Do not describe them as observed compiler/test failures. The provider cause
and exact unused-control retirement remain pending the separately prepared
[data-only diagnostic](../../../proposals/picker-allocation-checks.md).

Follow-up: [diagnostic and exact retirement passed](picker-allocation-diagnostic.md),
confirming provider macOS ARM capacity constraints. The original native attempt
remains unexecuted; no native acceptance or source-review defect execution is inferred.
