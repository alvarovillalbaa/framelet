# Native UI attempt 8: save panel window identity

Last updated: 2026-11-12

[Run 43191582002](https://github.com/alvarovillalbaa/framelet/actions/runs/43191582002),
job 131091959365, failed the single FUI01 case at source
`6c6c18fba92d8a6a3ecc0d1127572f4cfd610a56`. Rename, clip operations and named
Canvas/Layout/Background controls passed their native assertions; Square and
Sand were applied. The test stopped waiting for a Save button under a Dialog.
No MP4 or post-export verification ran. The full case remains failed.

The [diagnostic screenshot](native-ui-attempt-8-diagnostic-final.png) was viewed.
Its [original hierarchy](native-ui-attempt-8-diagnostic-final.accessibility)
exposes the modal NSSavePanel as a Window with identifier `save-panel`, filename
field `saveAsNameTextField`, and Save button `OKButton`. Its visible destination
is the owned fixture root. Attempt 9 selects those observed native identities;
application behavior and permissions stay unchanged.

The [complete receipt](native-ui-attempt-8.json) preserves native results,
partial saved project/source media, original diagnostics and all 34 complete
command streams, independently decoded and hash-verified. The
[full original log](native-ui-attempt-8.log.json) and
[retirement receipt](native-ui-attempt-8-retirement.json) retain failure and
cleanup evidence. All four owned cleanup checks passed. Artifact 13931217823
is 103,794,035 bytes with server SHA-256
`1290bde22928ba3d994f36009b3dff78cb9653ed09f4c3223c10616a2ea41d39`.
The exact workflow is disabled and its unchanged QA head retired; previous
failures and original accepted scopes keep their own results.
