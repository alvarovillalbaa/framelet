# Native UI attempt 5: Canvas lookup and compact-observer limit

Last updated: 2026-11-12

[Run 43184217179](https://github.com/alvarovillalbaa/framelet/actions/runs/43184217179),
job 131067276858, failed FUI01 at source
`a65b02697adba86b49ea730dd02e7eec0b281110`. Host fixtures and the native app
build/signature passed. Actual UI actions reached rename, trim, duplicate,
reorder and removal; the new clip accessible values satisfied their native
assertions. The test recorded the edited-clips phase, expanded the canvas
disclosure, then found no `PopUpButton` matching `Canvas`. The single case is
failed; no export, reopen, file-verifier or partial-case acceptance is claimed.

The [complete receipt](native-ui-attempt-5.json) preserves seventeen commands /
thirty-four complete streams, native test identity/failure and owned fixture
manifest/media. Its attachment observer separately hit its 4 MiB individual
bound on automatic XCTest video and retained no inline attachment array. This
observer failure remains false; it is not an application error. The
[complete log](native-ui-attempt-5.log.json) preserves original text losslessly.
The full native packet was uploaded as artifact 13927483704, size 98,057,941,
SHA-256 `c9e8a9831198623d7673ed096dc59c02eeae48859101211c0d1a928305d33496`.

Owned app/runner absence, unchanged source and owned library/scratch removal
passed. The [retirement receipt](native-ui-attempt-5-retirement.json) records
verified upload, removed runner packet, disabled workflow 415747099 and deleted
exact QA head `d899e6ba0708ff016030e9fe232205a2c30c2f61`.
The [data-only recovery scope](../../../proposals/native-evidence-recovery.md)
retrieves the already-saved screenshots/hierarchy before any further selector
change. It neither reruns FUI01 nor rewrites this failed result. Local artifact
download DNS failures do not prove missing remote evidence or an app defect.
