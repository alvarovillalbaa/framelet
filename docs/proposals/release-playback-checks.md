# FUI04: play the actual captured takes in the released app

12 November 2026. Standing owner approval to finish/publish every project and
"I approve everything / Keep going / Do all the work" covers this distinct
bounded native scope. [FUI03](../results/2026/11-12/capture-attempt-4.md), its
[0.1.3 package](../results/2026/11-12/capture-preview-attempt-1.md) and
[publication](../results/2026/11-12/capture-preview-publication.md) stay closed.
No new recording, source selection, export or permission action occurs here.

The app input is the exact retained 0.1.3/build 4 universal Release ZIP from
source `8486e830810699eb14786d7c8ce2780efb069bee`, SHA-256
`b4c0d15b6f89ba0df9645f3ea6f92b4a2b18ed3b5ac34b2ee8bd4a56fbadbccd`.
Its pinned raw package receipt supplies the payload manifest. Extract it only
inside the nonce-owned CI root, require its exact bundle files/bytes/modes,
strict signature and empty entitlements, then leave the app unchanged and
unresigned. This admits an existing runtime input; it does not repeat or extend
the closed universal packaging/publication qualification.

The current native Xcode project builds only the UI harness and its ordinary
Debug dependency. Never accept that Debug app as the tested product. Rewrite
only the generated xctestrun's sole `UITargetAppPath` and matching dependent
product path to the admitted Release bundle, retaining both original/bound
plists and exact edits. A read-only host process observer must see only that
released executable and match every native phase's actual application PID.
The real library uses the fresh VM account's default Application Support path,
admitted only when absent, with nonce/inode ownership; do not override HOME,
add a product test hook, change runner/app entitlements or modify TCC/settings.

Seed only FUI03's existing ready manifest and two original silent 640×428 MP4s,
each pinned by exact SHA-256. Preserve their title, IDs, durations, clip order
and presentation. No generated replacement video or copied audit tree. The
whole library (including its new ownership marker), source/index and released
bundle must remain byte-identical before/after native execution.

Run only `FrameletReleasePlaybackAcceptance/testFUI04PlayRealCapturedTakesInReleasedApp`:

1. Open the two-take recording, default Recording scope, zero position and
   disabled Start with no selected source. Waiting must not autoplay.
2. Play and observe the cursor advance; pause on red, verify the cursor freezes,
   resume without seeking and cross the real clip boundary to blue.
3. Seek the global timeline back to red and forward to blue while paused.
   Apple's [slider API](https://developer.apple.com/documentation/xcuiautomation/xcuielement/adjust%28tonormalizedsliderposition%3A%29)
   provides best-effort normalized interaction; also require the displayed
   position to reach the intended time within 1.5 seconds.
4. Select the second clip and Selected Clip scope: reset without autoplay,
   correct duration, active blue playback. Change to clip one: reset without
   autoplay, correct duration and red playback. Return to the full recording.
5. Seek near the end, play to automatic stop, then Play must restart at the
   beginning and show red. Normal Quit/reopen must retain both clips and play
   red again without automatically recording or playing.

Each colored observation is paused for a stable original XCTest screenshot.
The independent Swift/ImageIO verifier must decode all nine expected red/blue
phases, sampling the actual preview bracketed by observed scope/play/time
control frames at the screenshot's measured display scale. Reject black/wrong
colors, off-window/clipped anchors or mismatched original PNG hashes. The
initial paused frame has no color assertion; this does not qualify first-frame
thumbnail presentation. Retain ten phase PNGs, AX trees, UI/progress/shutdown
JSON, complete command streams, process bindings and fixture/bundle/source
guards. A green native case alone is insufficient.

Use the inactive `release-playback.workflow.yml.example` with one fixed public
`macos-15-intel` VM, maximum 20 minutes and 17-minute controller step. Controller
work budget is 900 seconds with command cleanup ending by 990 seconds,
native case allowances 360/420 seconds and owned
storage at most 4 GiB/32,768 entries; command streams at most 2 MiB each,
inline attachments 16 MiB, receipt 48 MiB and uploaded packet 256 MiB/2 days.
Build only the new pixel verifier and harness; do not execute old native/core/
pixel cases. No account, payment, model call, dependency or cloud database.

Native timeout/stream/group paths must never signal a possible app-writer
group. Require actual no-source/disabled-Start shutdown acknowledgment before
ordinary owned app/runner termination and library/root removal. Otherwise
retain partial files and report cleanup unverified. Preserve authored input
bytes and all failed originals before a changed candidate. Remove a passing
raw xcresult intermediate only after the complete native/process/pixel/hash/
cleanup verdict; preserve original attachments/identities/streams. After exact
artifact upload, retire only this workflow and its unchanged QA head.

Fresh local Storage Guard refused at 2.8 GiB free/34.0 GiB required. Local work
is source syntax/static inspection and bounded evidence handling only. This
profile, even if successful, proves only the exact Release/x86_64 VM playback
path. ARM Release runtime, first encoded-screen-anchor correspondence,
camera/audio timing, physical displays/devices, migration, human accessibility
and trusted downloaded-app/Gatekeeper launch remain separate open requirements.

[Attempt 1](../results/2026/11-12/release-playback-attempt-1.md) stopped at the
4 GiB apparent-storage assertion during harness build, before app/native
execution. Preserve its missing build streams and unverified root cleanup as
gaps. Candidate 2 keeps that same cap and all runtime/pixel/fixture assertions;
the changed controller records failing logical/allocated sizes, unique inode
counts and largest paths before rejecting. It retains observed command bytes,
EOF/truncation/stop/signal metadata on exceptions. Cleanup source/index guards
are read-only and may run after a storage refusal; only verified task-root
compiler/app/runner processes may receive ordinary termination after safe
no-native/actual shutdown admission. No inferred cache setting, larger cap,
product change, reduced playback scope or old-case replay is introduced.
