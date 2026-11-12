# FUI02 complete native window qualification — passed

12 November 2026. [Run 43202901167, attempt 2](https://github.com/alvarovillalbaa/framelet/actions/runs/43202901167/attempts/2),
job 131139855364, passed the complete FUI02 case at source
`2fb903989ac82bacfff6c96b72d18f6e24934db3` (tree
`ad2fd7b6d81876e59fe31a21eb160e0c962a0475`). One native case passed, with zero
failed/skipped/expected failures, on macOS 15.8.2/debug/arm64 with Xcode 16.4.
The unchanged source received one targeted rerun only after attempt 1 reached
[terminal runner-allocation failure](window-sizing-attempt-3-allocation.md)
without any build/test step. Both earlier native failures remain failed.

The live usable rectangle was `(0,25,1024,681)` at all four phases. Actual
native rectangles, observed in the single complete execution:

| Phase | Windows `(x,y,width,height)` |
| --- | --- |
| First launch | `(0,37,1024,657)` |
| Relaunch | `(0,37,1024,657)` |
| Additional library window | First `(0,37,1024,657)`; second `(0,39,1024,660)` |
| Relaunch after additional window | `(0,39,1024,660)` |

All four original screenshots were viewed:
[first](window-sizing-attempt-3-01-first-window.png),
[reopened](window-sizing-attempt-3-02-reopened-window.png),
[additional](window-sizing-attempt-3-03-additional-window.png), and
[reopened again](window-sizing-attempt-3-04-reopened-windows.png).
The normal macOS restoration preference reopened one window in the last phase;
the source does not disable restoration or force a saved-window count.
Strict containment retained its original one-point rounding tolerance.

The app uses display-aware SwiftUI placement, the 1180×820 preferred size,
900×600 minimum content, and twelve points of vertical room at each display
edge. Product changes are confined to `FrameletApp.swift`. There is no global
NSWindow mutation, production test hook or new permission. The sandboxed UI
runner's public AppKit metadata matched fixed host-admitted display resolution.
Authored source manifests/media were unchanged before/after the journey.

The [complete receipt](window-sizing-attempt-3.json),
[lossless original log](window-sizing-attempt-3.log.json), and
[retirement receipt](window-sizing-attempt-3-retirement.json) preserve evidence.
Independent data review decoded/hash-checked all 40 complete command streams,
every inline attachment and fixture file; source guards match. Owned app/runner,
library and scratch absence passed. Exported originals/native identities remain;
the passing raw xcresult intermediate was removed only after acceptance/cleanup.
Artifact 13937173567 is 1,484,032 bytes, server SHA-256
`c098dceab1414301abf084ca2f15be0c53c115e21760f29921b0949c9cc5d0fe`.
The exact native workflow is disabled and ref absent; the diagnostic control
is independently retired too.

This closes the observed small-VM default/reopened/additional-window defect
at that source/profile. It does not establish old-install migration, physical/
rotated/multiple displays, human accessibility, Release runtime, actual capture,
camera/audio timing or trusted downloaded-app launch. FUI01, earlier thirty
cases, retained-export pixels and old packaging were not replayed. The public
download remains 0.1.1 until the separate 0.1.2 package and delivery qualify.

Follow-up: the [0.1.2 universal package](window-preview-attempt-1.md) and
[unchanged public delivery](window-preview-publication.md) passed separately.
The original native result and its proof limits remain unchanged.
