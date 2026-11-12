# Actual-capture attempt 3 — two real takes; reopened export UI failed

12 November 2026. [Run 43225190964](https://github.com/alvarovillalbaa/framelet/actions/runs/43225190964),
job 131206448357, macOS 15.7.9/x86_64 Debug, Xcode 16.4. Source
`10837d5f93b74e0973ea8537f6b11c7ea43a8c4e`, tree
`bc1169b9efd010b4ffeb29b76dea3682c371dfeb`, native
`2504bde08136bf0b5ccd1f0fd97265ed863005e4`; QA
`72019e9e48c46593b8b2c50595d893084303f362`.

The full case remains failed: one failure, zero pass/skip/expected failures.
This time the real picker group/nonce-selected-filter guard passed. The app
recorded the authored window, used foreground Pause/Resume/Stop with its
library hidden, sealed two ScreenCaptureKit MP4s and returned ready. The native
UI reopened the project and observed two clips/available playback, but could
not scroll to Export because the restored library window was not hittable.
The final screenshot shows it minimized, with the fixture still visible.
The test used XCTest termination before relaunch; this does not establish
ordinary app-quit behavior or a shipping window-restoration defect.

All eight original phase PNGs were viewed:
[picker](capture-attempt-3-01-picker-open.png),
[owned target](capture-attempt-3-02-window-target.png),
[exact selected title](capture-attempt-3-04-owned-window-selected.png),
[red recording](capture-attempt-3-05-red-recording.png),
[paused blue fixture](capture-attempt-3-06-paused-blue-fixture.png),
[blue recording](capture-attempt-3-07-blue-recording.png),
[acknowledged Stop](capture-attempt-3-08-stop-acknowledged.png), and
[reopened failure](capture-attempt-3-diagnostic-final.png).
The [source geometry](capture-attempt-3-02-source-geometry.json) and original
AX retain the actual picker/recording/window state. No full-display, camera,
microphone or system-audio option was used. The Stop image visibly previews
the captured red window; independent media pixel/track inspection remains open.

Actual [manifest and original media](capture-attempt-3-files/library/Recordings/EB2F0180-5CD2-424F-B681-88B684007E99.framelet/manifest.json)
are retained, with ready status and two ordered full-take clips. First segment
`D7D55357-E8B2-492B-A858-54FFD735F1BA`: 11.208333333333334 seconds, 22,109 bytes,
SHA-256 `56da5b51d38d8dd3cab6f9e75de2d8b76c7f2e6884bbc5f70ceb98f26ffcf845`.
Second `A6FCAEA2-B3AE-4D78-B829-8E3250958B80`: 12.165 seconds, 23,485 bytes,
SHA-256 `9203671ce99c0c2d4b28a43837d641b8444568a20869dddbf37850bbdb6d4538`.
The [independent before-export snapshot](capture-attempt-3-files/originals-before.json)
completed at Swift uptime 339.73881619900004. Its manifest and both original
hashes exactly match the retained post-failure bytes. The compiled full AV/file
verifier did not run because the native case failed before Export; neither
duration fields nor screenshots replace that missing verdict. No export was made.

[Original receipt](capture-attempt-3.json), [lossless log](capture-attempt-3.log.json),
[shutdown acknowledgment](capture-attempt-3-capture-shutdown.json),
[artifact metadata](capture-attempt-3-artifact.json), and
[retirement receipt](capture-attempt-3-retirement.json) retain the result.
Receipt SHA-256:
`6b9403694548167516e6450615edb4a437d7b036dfb2e25ebfd81ccac189ee47`.
Forty complete command streams, two complete observer streams, fifty-one
inline attachments and five authored retained files were decoded/length/hash-
checked. Both 308-file source vectors match; all commands except native UI (65)
exit zero. The native group was never signalled. Actual shutdown records Start,
Stop and ready/source-controls acknowledgment, no export request, settled export
state and no forced writer termination. Only afterward did owned process,
library and root cleanup pass; all originals were retained first.

Artifact 13947329198 retains failed raw xcresult and original exports/media:
65,392,281 bytes, SHA-256
`aff95e4f63c400b2734bbc593ee5b9cbf5772fb486f63d4350970c1edb6acdbb`.
Workflow 416036110 was disabled; only its unchanged QA removed, independently
read back absent. Preserve all three original failures and the public 0.1.2 assets.

The [changed candidate 4](../../../proposals/authored-window-capture.md) uses
normal Command-Q only after acknowledged Stop, waits for app exit, relaunches
and restores its sole window through the scoped Window menu. Window titles
change to the recording title, so its observed native window identifier is
used instead of the old Library text. Require actual hittability before Export.
Always retain progress timestamps even on failure. Shipping capture/verifier/
fixture inputs and all media/pause/identity/shutdown requirements stay unchanged;
the complete new same-source native+file case remains required, not closed.
