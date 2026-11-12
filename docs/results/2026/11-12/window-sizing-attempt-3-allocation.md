# FUI02 candidate 3: runner never started

12 November 2026. [Run 43202901167](https://github.com/alvarovillalbaa/framelet/actions/runs/43202901167),
attempt 1, reports completed/failure. Job 131130604433 reports completed/
cancelled with zero steps, after queuing from 10:43:40 to 10:58:43 UTC.
No native build, test, fixture or in-job retirement ran. This supplies no app
acceptance or app failure diagnosis. Source remains
`2fb903989ac82bacfff6c96b72d18f6e24934db3`; unchanged QA head is
`1b631c87cb4da85fffbfb2ef0166cc84596452b5`.

The [original run/job snapshot](window-sizing-attempt-3-allocation.json) was
retained before any retry. The underlying executor reason is unverified:
connected GitHub fetch does not expose direct job/check annotation endpoints,
and the public annotation URL was unavailable through web access. Do not
invent a capacity, user-cancellation or application cause from this state.

A single targeted rerun of this cancelled job, at the same immutable source,
is appropriate because authoritative state is terminal and no app/test ran.
This is not an observation-timeout restart or replay of a completed scope.
Keep the original allocation verdict separate from any new run attempt and
verify the replacement job's actual identity, result and control retirement.
The 0.1.2 publication remains gated on a complete native FUI02 result.

Follow-up: the [data-only diagnostic](window-allocation-diagnostic.md) obtained
the original check annotations, establishing macOS ARM runner capacity failure.
The single targeted rerun [passed full FUI02](window-sizing-attempt-3.md).
The original allocation snapshot/verdict remains unchanged.
