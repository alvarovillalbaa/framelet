# Authored-window picker presentation/cancellation — passed

12 November 2026. [Run 43215226111](https://github.com/alvarovillalbaa/framelet/actions/runs/43215226111),
job 131172647800, passed the complete FUI03A case on macOS 15.7.9/x86_64 Debug,
Xcode 16.4/16F6. Source `8b1aa4c9469c1631eb5b0a8564f8e089d2fe0a4b`, tree
`6b5dc031ceb9741b0ee8c7165edbad1b26d8498d`, native source
`554114f1c67e97544ea9c6fbfa32a6a045e208ca`; QA
`da9e5b82fbcb3859076859a354f9fe34c38b822c`.

One case passed, zero failed/skipped/expected failures. The real authored
fixture and recorder compiled/launched with empty ad-hoc entitlements. The
native journey verified the exact nonce-titled fixture, initial unselected/
ready state, audio/camera off and disabled Start; opened the picker, pressed
Escape, and required unselected/ready state and disabled Start again. No source,
Share, Start or device/consent action occurred. The fresh owned library's
`Recordings` directory was empty; no Framelet recording was created.

All four original phase PNGs were viewed:
[fixture](picker-readiness-attempt-3-01-authored-fixture.png),
[ready](picker-readiness-attempt-3-02-recorder-ready.png),
[system picker](picker-readiness-attempt-3-03-native-picker.png), and
[cancelled](picker-readiness-attempt-3-04-picker-cancelled.png).
The system picker visibly appears and disappears. The actual
[Control Center AX](picker-readiness-attempt-3-03-system-01.accessibility) exposes
`Shared Content Picker Controls`, Show All Windows, Cancel and Share Built-in
Display. This is actual selector evidence for future work, not a successful
window choice. The [metadata inventory](picker-readiness-attempt-3-03-process-inventory.json)
retains 23 entries; only SystemUIServer and Control Center trees were queried.
No unrelated application tree was read.

The [original receipt](picker-readiness-attempt-3.json),
[lossless job log](picker-readiness-attempt-3.log.json),
[observations](picker-readiness-attempt-3-picker-observations.json),
[independent artifact metadata](picker-readiness-attempt-3-artifact.json), and
[retirement receipt](picker-readiness-attempt-3-retirement.json) retain the
evidence. Receipt SHA-256:
`522eb68d53ff9c08715b47f059d12a893ed83d2df86d805a165b71931ee34ca1`.
All 42 complete command streams and fourteen inline attachments were decoded,
length/hash-checked; every command exits zero with its child group absent.
Both complete 260-file source vectors match; shipping/closed-test inputs are
unchanged. Fixture bundle bytes and inode match before/after; its owned marker
was independently checked. Owned app/runner/fixture, library and scratch are
absent. The 170.05-second controller retained original exports and structured
Apple results before removing only its passing raw xcresult intermediate.

Artifact 13943362303 is 2,478,536 bytes, server SHA-256
`a18bd58ee3235e4258d901fc04f3be7a4ab9de1f9e9b803b282ca0d5130e2f84`.
Workflow 415955295 was disabled; only its unchanged QA ref was removed. The
entire task picker-ref prefix was independently observed empty. Both the
[unallocated ARM attempt](picker-readiness-attempt-1-allocation.md) and
[failed Intel diagnostic attempt](picker-readiness-attempt-2.md) retain their
original outcomes and proof limits. No closed FUI01/FUI02/package/pixel scope
was replayed, and no shipping product source changed.

The [fresh connected-tool ref readback](picker-controls-public-readback.json)
preserves that independent absence check.

This closes only picker presentation/cancellation on this Intel VM. Actual
window choice, SCRecordingOutput media, pause/resume/stop/export, first-sample
timing, camera/audio, physical displays, migration, trusted distribution and
human accessibility remain open. The [separate capture draft](../../../proposals/authored-window-capture.md)
must materialize the exact owned-window identity guard, full case and safe
Stop-acknowledged teardown before execution. Do not rerun this closed probe.
