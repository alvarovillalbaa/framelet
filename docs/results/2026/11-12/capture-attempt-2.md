# Actual-capture attempt 2 — duplicate menu selector before picker

12 November 2026. [Run 43223182288](https://github.com/alvarovillalbaa/framelet/actions/runs/43223182288),
job 131199638266, compiled the app/fixture/verifier/case on macOS 15.7.9/x86_64
Debug, Xcode 16.4. Source `02b244e570c42c5f40e1687e499d5944276e6761`,
tree `53464360abeb1cb7f88efa6fd882f193ba4d9408`, native
`b6ec1d49511df8ef595421a22584782596f01e6d`; QA
`d172264c24b8968563af2f029afc233e594876e4`.

One native case failed, zero passed/skipped/expected failures. Initial ready/
options-off assertions and native library minimization passed. The global
Choose Display or Window menu query matched both the foreground Recording
menu and the menu-bar status item, so XCTest rejected the ambiguous click.
The picker/owned group/selected-filter callbacks, Start, capture and export
did not execute. This is a test selector error; no permission was refused.

The [original failure PNG](capture-attempt-2-diagnostic-final.png) was viewed:
the library is minimized and Recording is open over the authored fixture.
[Recorder AX](capture-attempt-2-diagnostic-final.accessibility) and native failure
detail retain both menu branches. [Original receipt](capture-attempt-2.json),
[lossless log](capture-attempt-2.log.json),
[shutdown attachment](capture-attempt-2-capture-shutdown.json),
[artifact metadata](capture-attempt-2-artifact.json) and
[retirement receipt](capture-attempt-2-retirement.json) preserve the outcome.
Receipt SHA-256:
`4f551eddacff9747019fde380833a17a8a3415a2a55fa25c5275cc38b6869928`.

Forty complete command streams, seven inline attachments, two retained files
and the read-only observer's empty/incomplete streams were independently
decoded and hash-checked. Both 299-file source vectors match; all commands
exit zero except native UI (65). The observer was deliberately cancelled (-15)
after the failure and supplies no completed baseline. Native UI's possible-
writer group was never signalled. Actual shutdown metadata reports no capture/
export requested, safe termination and no forced writer termination; it is not
a Stop/ready proof. No recording/media was created. Ordinary owned app/runner/
fixture, library and root cleanup passed.

Artifact 13946414649 retains failed raw xcresult/exports: 51,412,223 bytes,
SHA-256 `7282d3ffd2c14c64cc86ceb8cd557e76c729e86b304e0b1fcaad33946b74c7ef`.
Workflow 416018946 was disabled; only its unchanged QA was removed and the
exact ref independently observed absent. Preserve this failed original.

The [changed candidate 3](../../../proposals/authored-window-capture.md) scopes
Choose/Pause/Resume/Stop to the foreground Recording menu and Library to its
Window menu. It does not pick the first global match. The exact owned-window
group/selected-filter guard, full two-take recording/export/file verdict and
acknowledged shutdown/retention limits remain unchanged and still required.
No shipping source, dependency, permission, device, paid service or model call
changes; closed scopes remain untouched.
