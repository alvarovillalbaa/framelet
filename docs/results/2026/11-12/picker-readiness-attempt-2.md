# Picker readiness attempt 2 — diagnostic-count assertion failed

12 November 2026. [Run 43213699586](https://github.com/alvarovillalbaa/framelet/actions/runs/43213699586),
job 131167466967, executed the one FUI03A case on macOS 15.7.9/x86_64 Debug
with Xcode 16.4. Source `7bf374d4b6ffcc57a44f1c681e3ba6466553c161`, tree
`089e82a5a86bb251338cd25b4fb0c7bbe7ebd5fa`, native source
`26666e69951923e3e3b43dc96e4d636255f839b7`; QA
`adb86c96e35570cee293fd389a6451e157a9ce35`.

The authored fixture and unchanged recorder built, ad-hoc signed with empty
production/fixture entitlements, and launched. Initial unselected/ready state,
disabled Start and audio/camera-off assertions passed. Choose Source entered
the choosing phase. The complete case then failed at its diagnostic assumption
that at most sixteen UI/accessory applications run; this fresh Intel VM reports
twenty-four. There is one native failure, zero pass/skip/expected failures.
This is a probe inventory-limit failure, not an observed Framelet defect.

All three original PNGs were viewed:
[authored red fixture](picker-readiness-attempt-2-01-authored-fixture.png),
[unselected recorder](picker-readiness-attempt-2-02-recorder-ready.png), and
[failure state](picker-readiness-attempt-2-diagnostic-final.png).
The failure image visibly shows the system picker with Cancel, Show All
Windows and Share Entire Screen; no source/Share/Start action was made. The
recorder's [actual picker-state AX](picker-readiness-attempt-2-03-picker-recorder.accessibility)
is retained. System-process trees, Escape/cancel/ready assertions and the
complete observation attachment did not execute. Do not claim them passed or
infer recording acceptance from picker pixels. Native XCTest's own automatic
authored-VM video is retained separately; Framelet never started capture.

The [original receipt](picker-readiness-attempt-2.json),
[lossless job log](picker-readiness-attempt-2.log.json), and
[retirement receipt](picker-readiness-attempt-2-retirement.json) preserve the
result. Receipt SHA-256:
`439dad53e6857da071e9396e1f2005ad280172fe0febd97f7d75ff0ea89dd31f`.
All 42 complete command streams, eight inline attachments and the owned marker
file were independently decoded and hash-checked. Native UI exits 65; every
other command exits zero. Exact source vectors match before/after. Fixture
after-hashes and the normal empty-library postcheck did not run after the UI
failure; those boundaries remain unverified. The retained library file census
contains only its owner marker.

Owned recorder/runner/fixture processes, nonce/inode-bound library and scratch
were verified absent. Artifact 13941699286 retains failed raw xcresult and
original exports: 52,584,988 bytes, server SHA-256
`b91c1f4e149018e16e8cb1a9d8368e7ff240ae2af23831b4fb2be144b48e82ae`.
Workflow 415943086 was disabled and only its unchanged QA ref removed; that ref
was independently read back absent. All earlier failures/releases stay intact.

The [changed candidate 3](../../../proposals/picker-readiness-checks.md) retains
the behavioral assertions, saves at most 64 process metadata entries first,
then queries at most eight relevant system processes. It keeps the same
authored/no-Start Intel scope and exact cleanup/retention limits. No shipping
source, permission, device, dependency, paid service or model call changed.

Follow-up: [changed candidate 3 passed completely](picker-readiness-attempt-3.md).
This original remains failed; its unexecuted later assertions are not backfilled.
