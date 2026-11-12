# Native UI attempt 3: respected runner sandbox

Last updated: 2026-11-12

[Run 43181140478](https://github.com/alvarovillalbaa/framelet/actions/runs/43181140478),
job 131057127804, failed FUI01 at source
`ac372597a2fe69aa49a4531128d6d0a4d1cdf958`. The native app/UI target built and
its production-style empty-entitlement signature verified. XCTest's own
sandbox then refused to create the fixture's segments directory in the host
application's library (`NSCocoaErrorDomain 513`, underlying `EPERM`). The
failure precedes media generation and `app.launch()`. No editor/export or app
launch result is accepted.

The [original receipt](native-ui-attempt-3.json) retains fifteen commands /
thirty complete streams, both unchanged source guards, the native failure,
automatic XCTest recording/issue attachment and the owner-only fixture state.
The [complete log](native-ui-attempt-3.log.json) preserves original UTF-8 text
losslessly. App/runner absence, unchanged source and owned library/scratch
removal passed. The [retirement receipt](native-ui-attempt-3-retirement.json)
records verified uploaded evidence, removed runner packet, disabled workflow
415727018 and deleted exact QA head
`3598b02d309dd3878a4a63d998241747d48538c0`.

Do not disable the runner sandbox, add entitlements, grant filesystem access or
retry its refused write. The changed fourth profile instead assigns filesystem
fixture work to the existing host CI controller, which already creates and owns
the disposable library under its current permissions. A separate non-shipping
Swift fixture tool prepares synthetic media and independently checks the actual
saved manifest/MP4 afterward. XCTest performs only native UI actions and visible
assertions; it never accesses that library. Production app bytes, entitlements,
defaults and the default library path remain unchanged. This preserves both
actual UI and independent file assertions without relaxing either boundary.
