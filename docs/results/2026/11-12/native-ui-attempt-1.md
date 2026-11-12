# Native UI attempt 1: control failure before build

Last updated: 2026-11-12

[Run 43154184954](https://github.com/alvarovillalbaa/framelet/actions/runs/43154184954),
job 130970162322, failed before creating controller resources, building or
launching the application. The workflow renderer replaced every `SOURCE_COMMIT`
substring, including the suffix in the `FRAMELET_SOURCE_COMMIT` environment key.
The controller therefore raised `KeyError: 'FRAMELET_SOURCE_COMMIT'` at entry.
FUI01 was not executed. This is a control defect, not an observed app failure.

The [complete original log](native-ui-attempt-1.log.json) is lossless UTF-8 text
inside JSON, preserving whitespace and the failed evidence admission (zero
files). No native controller receipt, fixture, app launch or cleanup is claimed.
The exception precedes the first temporary-directory creation in the immutable
source `39d9b55785d60a9034f7297af6bebf6351ac9ee8`.

The retirement step completed: workflow 415516695 read back as
`disabled_manually`, and exact QA head
`f9da9320382ba2f9253c0fde920eef3eb48329b3` was deleted. No uploaded evidence
folder was removed because none was created/admitted. The corrected control
uses the distinct `REVIEWED_SOURCE_SHA` placeholder, a new exact QA ref/workflow
path, unchanged application and unchanged FUI01 body. This is a changed control,
not an unchanged native test replay or a passing result.
