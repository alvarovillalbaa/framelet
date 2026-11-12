# Saved evidence recovered without native replay

Last updated: 2026-11-12

[Data-only run 43186585818](https://github.com/alvarovillalbaa/framelet/actions/runs/43186585818),
job 131075145970, passed at reader source
`f98e03abd90f5f4f3a72d22872690116316599cb`. No application, native build or test
was executed. Its [complete receipt](native-ui-attempt-5-recovery.json) binds
the original 98,057,941-byte ZIP to artifact 13927483704, the expected failed
run/head, server digest and every archive member hash. The original failed
FUI01 verdict remains unchanged.

The unchanged original is retained in an
[evidence-only prerelease](https://github.com/alvarovillalbaa/framelet/releases/tag/framelet-ui-evidence-20261112-attempt-5),
release 442693072 / asset 738757493, at failed native source `a65b0269`.
Asset size and server SHA-256
`c9e8a9831198623d7673ed096dc59c02eeae48859101211c0d1a928305d33496`
match the downloaded ZIP. The draft was published only after that verification.
It is explicitly failed-run evidence, not an application download or acceptance.

Both original PNGs and accessibility trees were recovered. The
[edited-clips screenshot](native-ui-attempt-5-02-edited-clips.png) was viewed:
the renamed recording, blue first preview frame, two ordered clips and exact
0.20–1.00 / 0.20–0.60 ranges are visible. The
[failed-state hierarchy](native-ui-attempt-5-failure.accessibility) reports
`Canvas and camera layout` as a disclosure triangle with value `0`, not an
expanded group. There are no Canvas/Background picker controls in that state.
The prior centre-label click did not expand the native disclosure; a missing
picker cannot establish a picker-label defect.

The changed sixth test clicks the observed disclosure arrow relative to its
native bounds and asserts value `1` before querying the picker. Its teardown
callback captures failure state even when XCTest aborts through Objective-C.
The observer now indexes/hashes every original attachment and retains large
automatic videos in the uploaded packet while keeping only bounded diagnostic
PNGs/trees/JSON inline. This fixes evidence collection without weakening FUI01
or the independent saved-project/MP4 assertions. All app code is unchanged from
the fifth source, including its clip accessibility repair.

The recovery control read back workflow 415763278 as `disabled_manually` and
deleted its exact unchanged QA head `202bf27261fe67fb0cd2e66b134fcb45c0bb02d5`.
No local heavy execution, model call, new account or paid plan was used.
