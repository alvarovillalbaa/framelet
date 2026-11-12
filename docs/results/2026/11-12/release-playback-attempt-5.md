# Native interactions passed; assembled-recording pixels failed

12 November 2026. [Run 43246697685](https://github.com/alvarovillalbaa/framelet/actions/runs/43246697685),
job `131281170477`, failed the complete FUI04 qualification at source
`9c46e847b2a552cb00f507c1db27b2f994fa1407`. Native head
`ec4fd2594b66a62a5cfb5ff7a7406ad0f39d7d72` matches tree
`98f706cef4a4003687aced40ce935823ba5aa247`. The profile was Xcode 16.4,
macOS 15.7.9/x86_64, exact unchanged 0.1.3 Release app and Debug UI harness.

The sole native case passed with no failures/skips/expected failures. All ten
phases completed: play/pause/freeze, continuous boundary, both global seeks,
both selected-clip durations/reset/playback, end/automatic stop/replay and
ordinary Quit/reopen/play/Quit. Actual native PIDs `3161` and reopened `7868`
both match only the extracted Release executable. No Debug app was accepted.
This interaction success does not close the full rendered-playback requirement.

The unchanged independent verifier rejected the first required red phase with
`red preview absent: 02-recording-red`, exiting with signal 4 after its
top-level thrown error. The complete stderr is retained. Original recording-
scope PNGs show black; visual inspection of original selected-clip PNGs shows
correct blue/red video. The original separate rendering-control PNG shows
correct red/blue in plain AppKit and red in both unclipped/clipped SwiftUI.
All four control players/items report ready, no errors, times above 3 seconds
and nonzero video bounds. This rules out a general inability of this VM/XCTest
path to capture these assets or SwiftUI-clipped AVPlayerViews. It narrows the
observed fault to assembled-recording playback; it does not establish the
precise composition cause or qualify another architecture/profile.

Preserve the failed verdict and unchanged released bits. The next bounded
diagnostic compares the exact composition builder with explicit immutable,
size, crop and frame-timing variants in a disposable read-only control. It must
not repeat the now-observed full interaction journey or substitute plain-source
pixels for a corrected product. Any shipping correction still needs complete
same-source native and independent product pixels before a new release.

All eighteen commands/36 complete original EOF streams, 26 inline attachments
and four authored inputs were independently decoded and byte/hash checked.
Both 432-file source vectors/index match. Released bundle/library inputs remain
unchanged. Actual no-source acknowledgment preceded ordinary product shutdown;
probe/app/runner, owned library and root cleanup passed. Maximum allocated
bytes: 484,057,088; maximum apparent bytes: 27,267,058,943 under the same exact
sparse-cache exception. Elapsed: 349.965 seconds.

[Raw receipt](release-playback-attempt-5.json): 3,819,079 bytes, SHA-256
`d0f9020bd7cc4fbd4d6a254eedb1b91e5606720cb97a2d6ca2f9f5803afda567`.
The [lossless job log](release-playback-attempt-5.log.json), ten original PNG/AX
pairs, observations/progress/shutdown and rendering-control PNG/AX/JSON preserve
all outcomes. Artifact `13958880863`: 8,105,805 bytes, SHA-256
`4bffb0ad1fa944004478c7701d8ef08c1dd6ef5dfcd4f92486a7b7e533d36e6f`.
[Retirement](release-playback-attempt-5-retirement.json) verified upload,
removed uploaded scratch, disabled workflow `416182787` and deleted unchanged
QA head `dc6dbb10538fa33bfc814f408d947ba6670170d1`. The exact ref was independently
read back absent. All four earlier failures remain unchanged.
