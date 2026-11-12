# Actual-capture attempt 1 — selection stopped before Start

12 November 2026. [Run 43220222375](https://github.com/alvarovillalbaa/framelet/actions/runs/43220222375),
job 131189550763, built the recorder, authored fixture, native case and file
verifier with Xcode 16.4 on macOS 15.7.9/x86_64 Debug. Source
`f74a28bbbc74d6cfb123bbb4834cc7b6d886995c`, tree
`0ae8d74ebb00c406877da04921c76e078f6c2d3c`, native
`ce485d9fcd1717d631c894dc4f24b58a45b7a10c`; QA
`8ca1b632213fc8777bda318689d8e08aa95c1b71`.

One native case failed, zero passed/skipped/expected failures. The new selected-
window metadata source compiled, but no selection callback/runtime name was
qualified. After Show All Windows, the case required a title-labelled button
that the actual picker did not expose. It failed at line 139 before Start;
this is a selector assumption, not a permission refusal or observed recorder bug.

All three original PNGs were viewed:
[picker](capture-attempt-1-01-picker-open.png),
[window choices](capture-attempt-1-02-window-choices.png), and
[failure state](capture-attempt-1-diagnostic-final.png).
The [actual system AX](capture-attempt-1-02-window-choices-system.accessibility)
contains anonymous window groups with the original window rectangles, while
the screenshot shows transformed thumbnails. No nonce-labelled button exists.
The authored window remains visible; no source, Share or Start action completed.
Pause/resume/stop/export and actual media verification did not execute.

[Original receipt](capture-attempt-1.json), [lossless log](capture-attempt-1.log.json),
[shutdown acknowledgment](capture-attempt-1-capture-shutdown.json),
[artifact metadata](capture-attempt-1-artifact.json), and
[retirement receipt](capture-attempt-1-retirement.json) retain the result.
Receipt SHA-256:
`78b5986af64f3c59e282a1438fca58ec54266d47dbfb2999ebf412dae0718eb2`.
Forty complete command streams and thirteen inline attachments were decoded,
length/hash-checked. Both 284-file source vectors match. Native UI exits 65;
every other command exits zero. The possible-writer process group was never
signalled. The separately owned read-only observer was cancelled (-15), with
empty stdout/stderr explicitly incomplete; this is not a completed baseline.
It and the retained owner/empty baseline bytes were independently hash-checked.

The actual shutdown attachment reports capture/export never requested,
export settled, safe termination and no forced writer termination. It does
not claim a Stop/ready acknowledgment. Only the owner marker and empty observer
stdout existed; no recording/media was created. Owned app/runner/fixture,
library and scratch were verified absent. Artifact 13945921847 preserves failed
raw xcresult/exports: 54,435,996 bytes, SHA-256
`0fd3787d61ce13ce1f132c7345c0ec5e6b69cb6b46fae651e5b2212851f6ee43`.
Workflow 415993576 was disabled, its unchanged QA removed and the exact ref
independently read back absent. Keep this original failed.

The [changed candidate](../../../proposals/authored-window-capture.md) avoids
transformed thumbnails: minimize the recorder through native UI, open its
Recording-menu picker, match one actual picker group to the exact nonce-titled
fixture's native rectangle, then hover/click that group's center. Its chosen-
filter nonce title must still match before Start. No full-display fallback,
permission bypass, capture/assertion relaxation, dependency, local build,
paid service or model call is introduced. All later capture/file/cleanup
requirements remain mandatory at the same source; compilation alone closes none.
