# Native UI attempt 4: real app observed, popup selector failed

Last updated: 2026-11-12

[Run 43182639018](https://github.com/alvarovillalbaa/framelet/actions/runs/43182639018),
job 131062106092, failed FUI01 at source
`694967dfed95464e315ca5c78991e66fb63a73d3`. Host fixture compilation and media
preparation passed with exact input hashes. The app/UI target built, its
production-style signature verified, and actual Framelet launched and rendered
the generated recording's red preview with enabled playback controls. No
permission setting or entitlement changed. The first phase is observed, not a
passing editing/export case.

The [original screenshot](native-ui-attempt-4-01-library-preview.png) was viewed:
the ready recording, first red frame, disabled capture Start without a selected
source, and unchecked camera/audio controls are visible. The
[original accessibility tree](native-ui-attempt-4-01-library-preview.accessibility)
shows `Recording Actions` as `PopUpButton`. The test incorrectly queried
`MenuButton`, causing its single failed case before rename, editing or export.
Two native scroll views exist; the first belongs to the sidebar, while the
recording editor contains Export. The clip buttons expose their selection labels
but no trim/duration value or child static texts in the native tree.

The [complete receipt](native-ui-attempt-4.json) retains commands, complete
streams, original attachments and generated library state, including manifest
and both source videos. The [complete job log](native-ui-attempt-4.log.json)
preserves original text losslessly. No post-export verification ran because
the UI case did not reach export. App/runner absence, source guards and owned
library/scratch removal passed. The
[retirement receipt](native-ui-attempt-4-retirement.json) records uploaded
artifact verification, its runner-copy removal, disabled workflow and exact
QA-ref deletion. Earlier failures remain independently false.

The changed fifth source corrects the popup selector and editor scroll target.
The observed missing clip information also motivates a small product repair:
clip selection buttons now expose the same trim range and duration as an
accessible value. Native UI assertions read that value, while the independent
host verifier still checks actual saved clip identities, order, ranges, original
bytes and decoded export. This adds usable accessibility information, not a
test-only app hook. All other application/core/resource/builder inputs remain
unchanged; old thirty-case and universal packaging scopes are not replayed.
