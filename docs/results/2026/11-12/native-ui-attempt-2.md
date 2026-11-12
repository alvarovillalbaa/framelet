# Native UI attempt 2: runner fixture path mismatch

Last updated: 2026-11-12

[Run 43154485278](https://github.com/alvarovillalbaa/framelet/actions/runs/43154485278),
job 130971119477, failed its single FUI01 case at source
`9fb9c35ec67cc16b2f3ff674a6dc44ba2594587c`. App/UI-target compilation, native
target-path binding, production-style empty-entitlement ad-hoc signature and
strict signature verification passed. This is not editor/export acceptance.

XCTest resolves Application Support inside
`com.alvarovillalbaa.FrameletAcceptance.xctrunner/Data`, while the controller
created the fresh production app library under the CI user's Application
Support directory. The test compared those distinct paths and stopped before
its owner-file read, media generation or `app.launch()`. The native report has
one failed test, zero passed/skipped, not an app launch or media failure.

The [complete receipt](native-ui-attempt-2.json) retains all fifteen commands,
thirty complete original streams, two equal source guards, exact failure text,
native test identity and the automatic XCTest screen recording in a hashed
gzip/base64 attachment. The [complete job log](native-ui-attempt-2.log.json)
is lossless UTF-8 text inside JSON. Owned app/runner absence, fresh-library
removal, unchanged source and scratch-root removal all passed. No source media
had been created. No screenshot or app UI is claimed as observed.

The [retirement receipt](native-ui-attempt-2-retirement.json) records the
uploaded artifact's server identity/digest check, removal of its runner copy,
workflow disable/readback and exact QA-ref deletion. The original failed
profile remains immutable. The changed third control uses the explicit
controller-supplied app-library path with its existing nonce/inode admission,
rather than inferring that path from the test runner. It changes no app source,
entitlement, sandbox, access grant or permission setting. It does not retry a
permission denial or replay an accepted case.

The third controller also retains the bounded generated manifest/media state
before removing its fresh library, including a partial edit if the next native
journey fails. This does not retroactively add media to this second run; its
fixture stopped before media creation.
