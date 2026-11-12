# Release app launched; native container selector failed before Play

12 November 2026. [Run 43240514963](https://github.com/alvarovillalbaa/framelet/actions/runs/43240514963),
job `131259327359`, failed the complete FUI04 case at source
`7edb06a7b5cd22a94856e300cb1d089be01259d6`. Native head
`e4e1a1ae7b19279f00e7e40068f00295d7436f73` matches tree
`64d45cf25c8a8459a25b0ab8df30b5e2fb58625e`. Actual profile was Xcode 16.4,
macOS 15.7.9/x86_64, exact 0.1.3 Release app and Debug UI harness.

The sparse-file accounting passed: maximum apparent bytes 27,193,312,322,
maximum unique allocated bytes 417,787,904. The strict three-leaf exception,
4 GiB allocated/all-other apparent caps, unchanged released payload/signature/
empty entitlements and full UI harness build all passed. The generated run
file changed exactly `UITargetAppPath` and its matching dependent app path.
Original/bound run-file hashes are retained in [the receipt](release-playback-attempt-3.json).

Host observations independently bind actual app PID `3689` from the native AX
tree to the released executable, with no observed Debug app. The library
opened with both ready captured takes and the correct title. FUI04 then failed
at `FrameletReleasePlaybackAcceptance.swift:64`: `showPreview()` repeatedly
required the `RadioGroup` container itself to be hittable. Native AX still
placed that group at `{710,417,802,24}` within the actual detail viewport
`{631,331,919,589}`, with Recording/Selected Clip radio-button children,
Play Recording, slider zero and `0:00 / 0:23` all present. No Play action ran.
One native case failed; none passed, skipped or expected-failed. Rendered
playback/pixel/end/reopen acceptance remains open.

The changed case should require its actual interactive Recording radio button
and play control to be hittable, and require scope/time anchors inside the
observed viewport. Read-only container/text frames remain geometry inputs,
not click targets. Add an original failure PNG to teardown for later diagnosis.
Keep every playback phase, timing/color/process/original guard and independent
pixel verifier intact. No product or entitlement change follows from this
test-selector failure.

All fifteen commands/30 complete original streams, three inline JSON/AX
attachments and four authored inputs were independently decoded and byte/hash
checked. Both 404-file source vectors and index match. Released bundle and
library bytes stayed unchanged. Actual no-source/disabled-Start acknowledgment
preceded app termination; owned app/runner, library and root cleanup passed.
Failed raw xcresult and its automatic screen-recording attachment remain in the
artifact; there is no canonical phase PNG to claim as visually inspected.

Receipt SHA-256: `9ba6bb45676579af427d5ea8c651ddffad4cdd8defc4bbf30b98ed5d7f5cc7ff`.
The [lossless job log](release-playback-attempt-3.log.json) and
[native AX](release-playback-attempt-3-diagnostic-final.accessibility) preserve
the actual failure. Artifact `13953744841` is 51,812,228 bytes, SHA-256
`889ab00420911f986f448a4dacaec1ace4824abbbe0a9492ba2e2a17d99f3394`.
[Retirement](release-playback-attempt-3-retirement.json) verified upload,
removed uploaded evidence scratch, disabled workflow `416145457` and removed
unchanged QA head `ad5df980fab5f8b129c4fd650fb2aaa761db05a0`. Its exact ref was
independently observed absent. Preserve both earlier storage failures unchanged.
