# Exact data-only composition control closeout

12 November 2026. Standing owner approval covers closing the exact temporary
controls after [the passed FUI04D diagnostic](../results/2026/11-12/composition-probe-attempt-3.md).
Original retirement accepted disable but failed immediate state readback before
branch deletion. The connected GitHub tools cannot read workflow state or
disable/delete these controls; retain that failed retirement and do not rerun
the native diagnostic. No product conclusion changes.

One public ubuntu-24.04 job, at most three minutes/two-minute Python step and
100-second controller, no app/build/test/model/service call or artifact write.
Require the hash-pinned original passed receipt, terminal exact source/run/job,
native/upload success and retirement-only failure, exact artifact bytes/digest
and unchanged source. Read current workflow state, disable once only if active,
and allow at most six successful read-only state polls two seconds apart.
HTTP/permission failures are retained without retry. Delete only the unchanged
exact native QA head after observed disabled state. Then similarly disable and
delete only this helper's exact own workflow/head. Any mismatch stops mutations.

Retain bounded original API response/error bytes, statuses and hashes in the
finally-emitted receipt, including failure; no secrets or credential inspection.
Do not claim access to ended-VM scratch. Native-owned-root cleanup is already
verified in its original receipt; this scope closes remote controls only.
Preserve every prior original and do not repeat a closed native/profile scope.
