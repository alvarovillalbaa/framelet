# Correct small-display default window placement

12 November 2026. Standing owner approval to finish the portfolio, "I approve
everything / Keep going / Do all the work", covers this bounded repair and
native qualification. The [prior FUI01 hierarchy](../results/2026/11-12/native-ui-attempt-9-04-reopened-library.accessibility)
records a reopened 1180×692 window at x=-78 on a 1024-pixel VM display, while
its first-launch window fit. This is a real app defect, not a failed FUI01 case.
Preserve the closed native edit/export result and public 0.1.1 release.

Use SwiftUI's `defaultWindowPlacement` on the library WindowGroup, fitting its
existing 1180×820 preferred content size to `context.defaultDisplay.visibleRect`.
Keep ordinary resizing and macOS restoration policy. No global window mutation,
new dependency, capture/device access, permission change or app test hook.
Apple's [window-placement guidance](https://developer.apple.com/videos/play/wwdc2024/10148/)
owns the API; its [restoration discussion](https://developer.apple.com/videos/play/wwdc2024/10149/)
also explains why a default size alone is not a restoration guarantee. Native
observations, rather than that API choice, must prove the repair.

Run exactly FUI02 in one temporary public macOS-15 job capped at 20 minutes,
using the existing native app/XCTest project, default app entitlements and
sandboxed UI runner. A nonshipping AppKit helper reads only the fresh VM's
single-display usable bounds; refuse a display that does not reproduce the
observed width below 1180. Seed the existing authored silent media into an
absent nonce/inode-owned library. Check complete window bounds after first
launch, relaunch, opening a second library window, and relaunching again.
Record original PNG/AX and frame observations. Read usable bounds live at each
phase, keeping the pre-launch host admission separately because the Dock's
usable region may change. The UI runner reads public AppKit display metadata;
it gains no app-library file rights. Allow 600-point minimum content height
so native chrome can fit the observed small usable area. Do not replay FUI01, the old
thirty cases, old packaging or their retained-export pixel check.

[Attempt 2](../results/2026/11-12/window-sizing-attempt-2.md) exposed a further
three-point vertical overflow when opening an additional window. Candidate 3
keeps twelve points of vertical room at each display edge before placement;
horizontal sizing and strict checks remain unchanged. Preserve both failures
and require the whole new FUI02 run to pass at one source.

Verify native summary/identity, actual frame containment, unchanged fixture
manifest/media, unchanged source, owned process/library/scratch cleanup,
bounded complete logs/attachments and exact control retirement. Preserve any
failure before a changed repair. A separate 0.1.2/build-3 universal packaging
profile and unchanged-asset publication follow only after this repair passes,
without replaying closed scopes. Keep prior release/tag/assets intact.

Storage Guard measured 7.3 GiB free against 34.0 GiB required: no local build,
app/test/native execution, install or environment. Source parsing and bounded
evidence handling only. Live capture/permissions, physical devices/audio timing,
trusted download launch and full recorder parity remain open. A single VM is
not physical multi-monitor/rotated-display or human accessibility proof.
