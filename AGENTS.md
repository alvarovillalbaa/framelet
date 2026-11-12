# Framelet agent instructions

- Native, local macOS recorder. Keep recordings, camera/audio data, and edits on the user's Mac. No network, account, telemetry, or hosted dependency is required.
- Use first-party SwiftUI/AppKit, ScreenCaptureKit, AVFoundation, and AVKit. Preserve the screen/camera timing contract in `docs/specs/recorder.md`.
- Capture, permission prompts, microphone/camera use and UI automation need an explicit bounded execution scope. Dependency/CI changes and signed distribution follow the workspace approval gates. Source publication is covered by the owning project task; native builds/tests must respect Storage Guard and the approved verification scope.
- Never run the app, record screens, enumerate user windows, or request device access as an incidental verification step.
- Preserve source packages and partial media after failures. Never silently delete a recording or overwrite an export. Trash only the package explicitly selected by the user.
- Follow the workspace Storage Guard before building or installing. Do not bypass a failed reserve check.
- Use `script/build_and_run.sh` for local build/launch; its `--build-only` mode must never launch the app.
- Keep verification boundaries explicit: syntax parsing is not typecheck, build, capture, audio synchronization, export playback, signing, or notarization proof.

## Approved preview distribution — 8 November 2026

Standing owner approval covers [universal preview packaging](docs/proposals/preview-package-checks.md):
extend the builder with a non-launching `--build-preview`, one fixed public Mac
CI job capped at 20 minutes, Release arm64/x86_64 build, ad-hoc bundle/ZIP
round-trip verification, checksum/manifest and a GitHub prerelease. No paid
identity, notarization, store, device, account, capture or app launch. Preserve
all app/package/resource source and the old 30-case evidence; do not rerun it.
Only the builder changes among its 38 original inputs. Every new profile keeps
its actual source/toolchain/architecture boundary.

Storage Guard failed at 9.9 GiB free/34.0 GiB required. No local environment,
build, app/test/CLI/server or capture execution. Static syntax/source inspection
and bounded evidence handling only. Own and verify CI exports, caches, children,
archives and cleanup; preserve failures and retire the temporary execution path.

The [first preview control](docs/results/2026/11-08/preview-package-attempt-1.md)
failed before any build because Mac Python lacks `os.listxattr`. Its cleanup
is unverified. Standing approval covers a changed control using bounded
read-only macOS native attribute APIs via standard-library `ctypes`, with the
same builder/application source and fresh packaging checks. Preserve the first
failure; no new dependency, attribute mutation, app launch or test rerun.

The [second preview control](docs/results/2026/11-08/preview-package-attempt-2.md)
verified native metadata/cleanup but Xcode's build service crashed before
compilation. Standing approval covers the changed native single-architecture
Release builds plus `lipo`, preserving the full universal output/checks and
both failed originals. No unchanged Xcode retry, weaker architecture target,
old-test rerun, app/device action or new dependency is authorized by this fix.

[Attempt 3](docs/results/2026/11-08/preview-package-attempt-3.md) now passed the
full universal Release packaging/ZIP round-trip and owned cleanup. Both earlier
failures remain immutable with their false/true cleanup outcomes. Do not repeat
the closed packaging or old 30-test scopes. Publish unchanged retained assets;
record actual release/tag/digest readback. The archived controller guards its
original checked source, not later status-only main. App/device/trust gates
remain open, and temporary controls must stay disabled/retired.

The [preview is public](docs/results/2026/11-08/preview-package-publication.json)
at `v0.1.0-preview.1`, with all three unchanged asset server digests verified.
Main has no active workflow files; both provider workflow records are disabled
and all three QA controls retired. Do not turn public metadata into a fresh-Mac
launch or Gatekeeper/capture acceptance claim.

## Native editor qualification — 12 November 2026

Alvaro's standing "I approve everything / Keep going / Do all the work" covers
the separate [FUI01 native UI scope](docs/proposals/native-ui-acceptance.md).
This is an explicit app-launch/edit/export journey with generated media in a
fresh nonce-bound CI library, not an extension of the non-launching preview
profile. Use only its bounded temporary public Mac runner and preserve actual
failure/cleanup evidence. No source picker, screen recording, camera/microphone,
personal media, paid identity or old accepted-scope rerun. All existing product
inputs stay unchanged unless observed native evidence identifies a real defect.

[FUI01 passed](docs/results/2026/11-12/native-ui-attempt-9.md) at its exact
debug/arm64 source. Its native UI and independent file verifier are closed;
do not replay them as routine follow-up. Preserve all eight failed originals.
Standing approval covers the separate [0.1.1 preview refresh](docs/proposals/preview-refresh-checks.md),
including read-only analysis of the retained MP4 and a new non-launching
universal Release package. Only version metadata/builder guard change among
the qualified product inputs. Keep the old controller and release intact.

The [0.1.1 refresh passed](docs/results/2026/11-12/preview-refresh-attempt-1.md),
including retained-export Sand pixels and both Release slices. Do not repeat
the closed build/inspection scope. Publish its three unchanged, hash-pinned
assets through the bounded data-only publication helper; retain exact public
tag/server/anonymous-download evidence and retire only its temporary control.
Keep capture, trust, physical devices and observed narrow-window clipping open.

[0.1.1 publication passed](docs/results/2026/11-12/preview-refresh-publication.md):
the three retained assets have exact server digests and anonymous downloaded
bytes. All new task controls are disabled/removed. Three older retired 0.1.0
QA refs remain preserved; do not interpret their existence as active execution.
No routine check/publication rerun is needed. The next concrete app defect is
the 1180-pixel default reopened window exceeding the 1024-pixel VM display;
its correction needs a fresh bounded native window-sizing profile, preserving
this release and the closed FUI01/packaging evidence.

Standing approval covers the [focused window-sizing repair](docs/proposals/window-sizing-checks.md)
and FUI02 native profile in a bounded disposable Mac CI job. Preserve the
existing FUI01/test bodies and 0.1.1 artifacts; native frames must prove the
new placement rather than source inspection alone. No capture/device prompts,
account, dependency, permission change or local execution is in this scope.

[FUI02 attempt 1 failed](docs/results/2026/11-12/window-sizing-attempt-1.md)
at its initial height assertion. Preserve the original result. The changed
candidate lowers the content minimum to 600 and observes live usable bounds
per phase through public AppKit metadata. Keep strict containment, fixed
resolution and the normal runner sandbox; no new filesystem rights or capture.

[Attempt 2](docs/results/2026/11-12/window-sizing-attempt-2.md) passed first/
reopened assertions but failed the complete case on three-point additional-
window overflow. Keep it failed. The changed placement reserves twelve points
vertically at each display edge; require all FUI02 phases at the same source
with the existing strict tolerance. No old-scope replay is needed.

[FUI02 passed](docs/results/2026/11-12/window-sizing-attempt-3.md) completely
at source `2fb903989ac82bacfff6c96b72d18f6e24934db3`. Its first executor attempt
never started because of [provider capacity](docs/results/2026/11-12/window-allocation-diagnostic.md);
one targeted rerun qualified the same source. Keep both native failures and
the separate allocation failure. Do not replay this closed window case.
Standing approval covers its [0.1.2 non-launching package/delivery](docs/proposals/window-preview-checks.md).
Keep FUI01/pixel/old test scopes closed and import their evidence only.

The [0.1.2 universal package passed](docs/results/2026/11-12/window-preview-attempt-1.md)
at its exact source. Both Release slices and fresh ZIP/signature round trip are
closed; publish only the three retained assets through the prepared bounded
data-only helper. Preserve both older previews, their seven total assets with
the failed-evidence archive, and original native/allocation failures. Verify
anonymous byte/digest delivery and retire the exact publication control.

[0.1.2 is public](docs/results/2026/11-12/window-preview-publication.md), with
three matching server digests and anonymous downloaded bytes. Native window,
Release packaging and publication scopes are closed; do not replay them as
routine follow-up. All temporary window/allocation/package/publication controls
are retired. Preserve older releases and all failed originals. The separate
[actual authored-window capture draft](docs/proposals/authored-window-capture.md)
is next; materialize its bounded fixture/case/teardown before activation and
do not substitute synthetic input media for real capture acceptance.

Standing approval covers the separate [FUI03A picker readiness probe](docs/proposals/picker-readiness-checks.md)
in one fresh bounded Mac CI job: authored AppKit fixture, unchanged recorder,
native picker presentation/Escape and original VM screen/AX evidence. No source
selection, Share, Start, permission/device acceptance or actual recording occurs.
Review the real picker evidence before materializing capture selectors. Its
no-Start teardown is not suitable for live writers; actual capture still needs
Stop/finalization acknowledgment before termination or library removal.
If the first picker job never acquires an executor and becomes terminal, use
only its [conditional diagnostic/retirement scope](docs/proposals/picker-allocation-checks.md).
It must remain inactive while that native attempt is queued/running; no native
acceptance follows from a data-only cleanup or a changed runner profile.

The [first picker execution](docs/results/2026/11-12/picker-readiness-attempt-2.md)
built/launched the actual Intel app/fixture and visibly opened the system
picker, then failed on an overly strict process-inventory cap. Keep it failed
and its unexecuted cancellation/after-hash assertions open. Standing approval
covers the changed bounded diagnostic case in the same proposal: metadata
first, at most eight relevant system AX snapshots, unchanged picker/Escape/
ready behavior and no source/Share/Start or consent action. Do not weaken the
behavioral assertions or turn these screenshots into actual capture proof.

[FUI03A passed completely](docs/results/2026/11-12/picker-readiness-attempt-3.md)
on the exact Intel source/profile, with original PNG/AX, fixture/source/file
checks and owned cleanup verified. All picker controls are retired. Preserve
the two different failures and do not replay this closed probe. The next scope
is actual owned-window selection and capture, with exact source identity before
Start and acknowledged Stop/no unfinished writer before termination/removal.
Its file verifier remains syntax-only; materialize the full case/controller
from the capture draft before activating another native job.

Standing approval covers the now [materialized FUI03 authored-window capture](docs/proposals/authored-window-capture.md)
case/controller: only the exact nonce-titled AppKit window, camera/microphone/
system audio off, two real ScreenCaptureKit takes, native Pause/Resume/Stop,
reopen/export and independent media/original-hash verification on one bounded
public Intel VM. Working source names the chosen window via macOS 15.2 filter
metadata, retaining its 15.0 fallback. No personal content, full-display fallback,
TCC/settings changes, denied-permission retry, dependency, paid identity/service
or model call. Exact selected-window identity is mandatory before Start.
Require actual capture shutdown and export settlement before app signals or
library/root removal; otherwise retain partial files and unverified cleanup.
The read-only hash observer owns no writer. Keep all closed scopes untouched.

[FUI03 attempt 1](docs/results/2026/11-12/capture-attempt-1.md) compiled all
inputs but failed its title-button selector before Start. Preserve that failed
original and its no-writer/ordinary-cleanup boundary. Standing approval covers
the changed selector in the same full scope: native library minimize, matching
the exact nonce-titled fixture frame to one actual picker group, group-relative
hover/click, and unchanged selected-filter nonce guard before Start. No Expose
geometry, raw coordinate guesses, display fallback, permission change or
capture/file/assertion relaxation. All later Stop/export acknowledgments and
retention limits remain mandatory; do not claim actual recording from a build.

[FUI03 attempt 2](docs/results/2026/11-12/capture-attempt-2.md) failed the duplicate
Choose menu query before opening the picker. Keep it failed with its original
no-Start/ordinary-cleanup boundary. Standing approval covers the changed menu
scoping: use the foreground Recording menu's own children for capture commands
and Window's own child for Library; no first global duplicate or relaxed
capture/file/acknowledgment assertion. Shipping/verifier/fixture inputs stay exact.

[FUI03 attempt 3](docs/results/2026/11-12/capture-attempt-3.md) produced two real
sealed window takes and acknowledged Stop, but its complete case failed at the
minimized reopened export UI. Retain all actual media/original hashes and the
failed verdict. Standing approval covers the changed native reopen flow:
ordinary Quit after Stop, explicit sole-window restoration via its scoped
Window menu and actual hittability before Export, plus failure progress data.
No inferred product lifecycle change, shipping/verifier/fixture modification,
relaxed media/pause/identity assertion or closed-scope replay. Full same-source
native+file/cleanup evidence remains required before capture/preview closure.

[FUI03 passed completely](docs/results/2026/11-12/capture-attempt-4.md) at
`e1c3b5ea9013630375a9d5b29b7749784255d504`: exact authored-window selection,
real silent takes, Pause/Resume/Stop, normal Quit/window restoration/export,
independent decoded media/original hashes and acknowledged owned cleanup.
All three failures remain preserved and the capture control is retired. Do
not replay this closed native case. Standing owner approval covers a separate
0.1.3/build 4 non-launching universal preview refresh for the qualified selected-
window naming change, with pinned FUI03/FUI02/FUI01 evidence, both Release
slices, unchanged-asset publication/digests and exact temporary retirement.
No old native/pixel/core replay, audio/device capture, paid identity or trust
claim follows from packaging. Preserve all older releases and original evidence.

The [0.1.3 package/delivery scope](docs/proposals/capture-preview-checks.md)
is materialized with inactive exact-source controls. Execute only that new
non-launching package; publish only its retained assets after it passes.

[0.1.3 packaging passed](docs/results/2026/11-12/capture-preview-attempt-1.md)
with both Release slices and fresh ZIP/signature verification. The package
control is retired. Do not replay the closed package/native scopes. Publish
only its three retained hash-pinned assets using the new bounded data-only
control; verify server/anonymous byte delivery, preserve all ten older assets
and tags, and retire only that exact publication path.

[0.1.3 publication passed](docs/results/2026/11-12/capture-preview-publication.md):
three exact server digests/CI anonymous downloads, tag/source, ten older assets
and tags unchanged, owned scratch cleanup and exact control retirement. Fresh
connected metadata readback passed; an additional local anonymous fetch failed
and provides no download proof. Do not retry or replay closed capture/package/
publication scopes. Preserve all failures and older retired refs. First encoded
screen-anchor timing, camera/audio, real preview playback of these takes,
physical displays/devices, migration, human accessibility, Release runtime and
trusted downloaded-app launch remain open; continue with one bounded ready scope.

Standing owner approval covers the materialized [FUI04 Release playback scope](docs/proposals/release-playback-checks.md):
one bounded Intel VM, exact retained 0.1.3 Release bundle, already-authored real
capture originals, native playback/pause/seek/scope/end/reopen and independent
rendered pixels plus actual executable-PID/file/source/cleanup proof. No new
capture/source/export/device action, permission/entitlement/dependency change,
Debug-product substitution or closed-case replay. Local Guard now refuses at
2.8 GiB/34.0 GiB; source parsing and bounded evidence only locally. Keep the
full same-source native/pixel/process/unchanged-input verdict mandatory, retain
failures and retire only the exact prepared playback control.

[FUI04 attempt 1](docs/results/2026/11-12/release-playback-attempt-1.md) failed
its apparent-storage sampler during harness build, before app/native launch.
Keep it failed with its missing command/cleanup proof. The changed candidate
records failing size/topology and retains command streams on exceptions while
allowing read-only source/ownership cleanup inspection after refusal. Preserve
the same 4 GiB cap, released product, native case, all pixel/runtime/file
assertions and no-capture boundaries; diagnose actual storage before choosing
any further correction. No unchanged retry or closed-scope replay.

[Candidate 2 measured](docs/results/2026/11-12/release-playback-attempt-2.md)
three exact Xcode sparse-cache leaves totaling 25 GiB logical but zero allocated
blocks at refusal, with only 129,843,200 allocated bytes across the whole root.
Standing approval covers the proposal's explicit candidate-3 exception for
those three canonical single-link files and measured size maxima only, capped
at 29 GiB namespace, 4 GiB all-other apparent bytes and 4 GiB unique allocated
blocks. No local Guard exception, larger physical allowance, cache toggle,
runtime-case/verifier/product change or relaxed behavioral assertion. Preserve
both failures and require full native/pixel/process/unchanged-file/cleanup proof.

[FUI04 candidate 3](docs/results/2026/11-12/release-playback-attempt-3.md) built
the harness and launched the exact Release app, then failed on the RadioGroup
container's hit check before Play. Preserve its failed verdict. Standing
approval covers the changed native selector: actual play-control hit target,
existing scoped radio button, viewport-contained scope/time frames and original failure PNG.
All playback/pixel/process/file/cap/shutdown assertions and released bits remain
mandatory. No product change or accepted-scope replay is inferred from launch.

[FUI04 candidate 4 failed](docs/results/2026/11-12/release-playback-attempt-4.md)
after partial play/pause/boundary/seek behavior. Preserve its originals, including
the black preview frames. Standing approval covers candidate 5 in the same
proposal: require strict viewport containment before leaving the scroll loop,
then run the complete unchanged playback/color semantics. Add only a separate
muted read-only AppKit/SwiftUI rendering diagnostic after acknowledged product
shutdown, using the same pinned authored files and original PNG/AX/status JSON.
No product patch is inferred until the control distinguishes likely causes.
Keep exact released bits, all independent pixel/process/file/cleanup assertions
and existing limits. The diagnostic never substitutes for product acceptance.

[FUI04 attempt 5](docs/results/2026/11-12/release-playback-attempt-5.md) passed
all native interactions but failed the required Recording pixels. Selected Clip
and plain/clipped controls render correctly. Preserve the failed full verdict.
Standing approval covers only the new [FUI04D composition diagnostic](docs/proposals/composition-probe-checks.md):
six read-only muted variants, same real originals and unchanged shipping code,
no Framelet launch or full-case replay. Preserve that case as an exact file
prefix; require helper PID/AX/source/file/ordinary shutdown proof, retain its
raw native result and inspect actual frames before choosing a product fix.
The same measured sparse exception is explicitly scoped in the new proposal;
local Guard, physical caps, no-device/no-writer and exact-retirement gates remain.

[FUI04D attempt 1](docs/results/2026/11-12/composition-probe-attempt-1.md) has
original comparison frames but failed independent executable binding. Keep it
failed. Standing approval covers the proposal's changed canonical-process-path
observer, compiled-helper before/after hash and render-scale/postprocessing/
software-control comparison. Same native case and shipping/full-FUI04/pixel
inputs remain unchanged. Denied paths are retained without permission retry;
unexpected product launch blocks cleanup. Require actual identities and original
frames before choosing a shipping correction; no synthetic acceptance.

[FUI04D attempt 2](docs/results/2026/11-12/composition-probe-attempt-2.md) stopped
at an unavailable historical Git object before compilation. Preserve it.
Standing approval covers the changed exact original-case byte/hash pin, with
the same native/helper/product inputs and protected current-source diff. No
deeper checkout, execution-scope expansion or weakened identity/pixel assertion.

[FUI04D attempt 3](docs/results/2026/11-12/composition-probe-attempt-3.md) passed
the exact diagnostic and owned cleanup. Built-in video-composition panes remain
black while software/raw controls render. Do not replay this closed diagnostic
or infer wider product acceptance. Original retirement failed state readback;
standing approval covers the separate [data-only exact closeout](docs/proposals/composition-retirement-checks.md),
with bounded state observation, artifact/head guards and no native/app rerun.
Keep every failed original and the full FUI04 product-pixel requirement open.

The [data-only closeout passed](docs/results/2026/11-12/composition-control-closeout.md):
exact artifact/receipt and 15 original API responses verified; both target/self
workflows observed disabled and exact heads absent. Do not replay the closed
FUI04D/retirement scopes. The next product scope is compatible Recording
rendering with the existing geometry/timing/audio contract and new full pixel
acceptance; preserve the public 0.1.3 assets and all original failures.

Standing approval covers the new [compatible-preview repair and six encoded-frame cases](docs/proposals/software-preview-checks.md).
Only Recording's preview compositor/wiring changes among protected product
inputs; retain the existing geometry/timeline/audio and all capture/export/
Selected Clip paths. Run only its six new read-only image cases first on the
bounded public Intel VM, preserving failed originals and exact cleanup/control
retirement. No sparse exception, local build or old-scope replay. These checks
cannot qualify a full app or new public asset; prepare a separate exact-source
Release/native/nine-color profile after they pass. No new permission/provider.

[Software-preview attempt 1](docs/results/2026/11-12/software-preview-attempt-1.md)
failed a signal-zero observer before pixel checks and lost two command/cleanup
records. Keep the failure and proof gaps. Standing approval covers only the
proposal's read-only process metadata replacement, guarded ownership, guaranteed
stream retention and independent cleanup checks. Do not retry the denied query
or grant rights. Compositor/model and all six verifier cases remain exact;
full pixel/source/input/cleanup proof is still required before advancing.

[Software-preview attempt 2](docs/results/2026/11-12/software-preview-attempt-2.md)
retains complete streams and unchanged fixture bytes but failed topology
admission and source/root cleanup. Standing approval covers the proposal's
bounded compiler-cache alias metadata policy, pre-refusal snapshots, independent
cleanup observation and exited-child reaping. Preserve all missing proof; no
denied signal retry, rights grant, sparse/size extension or product/verifier edit.

[Software-preview attempt 3](docs/results/2026/11-12/software-preview-attempt-3.md)
passed controls/cleanup and failed native compositor compilation. Standing
approval covers only its corrected crop/opacity Swift labels and Sendable
dictionary types, with unchanged model/algorithm/six pixel cases. Preserve all
three failures; require the full six-case same-source result before Release work.

[Software-preview attempt 4](docs/results/2026/11-12/software-preview-attempt-4.md)
passed all six cases/eight original frames and source/input/group/root checks.
Both compilers emitted no stderr; exact control retirement passed. This
component scope is closed; do not replay it routinely. Preserve all failures
and the public 0.1.3 assets. Standing approval covers a distinct 0.1.4/build 5
universal package followed by full unchanged FUI04 native/nine-color/process
qualification of that exact Release app, materialized before each execution.
Component images alone are not app/UI/Release acceptance or publication proof.

The [0.1.4 non-launching package](docs/proposals/compatible-preview-checks.md)
is materialized with inactive exact-source controls. Run only its new universal
build/round-trip scope, preserving the accepted component source and all closed
cases. An inactive [full exact-Release draft](docs/proposals/compatible-playback-checks.md)
may be prepared while queued; its missing receipt pin rejects execution. After
the package passes, finalize the exact pin and reviewed profile before activation;
do not publish a new binary from packaging or component images alone.
