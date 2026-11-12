# Executor allocation diagnostic — passed

12 November 2026. [Data-only run 43206671295](https://github.com/alvarovillalbaa/framelet/actions/runs/43206671295),
job 131143449003, read the original cancelled job through its public GitHub
check metadata. Source `685b7ef94501a0640ff52b36831acf5fc9f3ce71`, exact tree
`7f1dd14c6c805212fb951be3ac3e5a832ca0b265`, was independently reconstructed
from the unchanged base plus the three published diagnostic inputs.

The failure annotation says the hosted runner never acquired the job. Notices
explicitly identify macOS ARM capacity constraints and longer queue times.
This establishes executor allocation failure, not app failure, a user request
to cancel, billing exhaustion or a permission refusal. It ran no app/build/test
and did not mutate the already queued native rerun.

The [complete diagnostic](window-allocation-diagnostic.json) and
[lossless job log](window-allocation-diagnostic.log.json) retain originals.
The helper used scoped public check reads through its ephemeral workflow token;
the connector's missing annotation route and unavailable browser host were
capability limits, not reasons to weaken authentication. Workflow 415895713 was
disabled and only diagnostic QA head `5b94e4cde710cc0193b363cbb029d592db009a95`
removed. Independent ref-prefix readback is empty. The native rerun subsequently
[passed its full scope](window-sizing-attempt-3.md) and retired its own control.
