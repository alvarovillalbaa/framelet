# Next recorder requirement: actual authored-window capture

Draft dependency scope, 12 November 2026. FUI02 and its downloadable 0.1.2
preview have closed. The separate [picker readiness probe](picker-readiness-checks.md)
first materializes the authored fixture and observes native presentation/cancel;
it never selects a source or starts capture. The original [recorder contract](../specs/recorder.md)
requires actual capture/pause/resume/export proof; the existing authored-media
edit/export, window and packaging profiles do not supply it.

[FUI03A presentation/Escape passed](../results/2026/11-12/picker-readiness-attempt-3.md)
on the Intel VM with actual picker pixels and Control Center AX. It is closed;
do not rerun its case. The observed system application is `com.apple.controlcenter`,
dialog `Shared Content Picker Controls`, with Show All Windows, Cancel and
Share Built-in Display buttons. The display-share action is outside this
window-only scope. Window choice itself has not been attempted; stop before
Start unless the exact nonce-titled fixture is independently identified.

The current recorder shows only generic Selected window. Before actual capture,
prepare the small user-facing improvement that names the selected window from
the chosen filter's metadata. Apple's [includedWindows](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/includedwindows.md)
and inspected SDK header mark it available from **macOS 15.2**. Preserve macOS
15.0 compatibility with an availability guard/fallback; do not raise the app's
minimum OS or enumerate unrelated shareable content to obtain a title. The
new capture case must require the exact fixture title before Start. This source
improvement, versioned preview refresh and native proof are not implemented by
the current draft. The public 0.1.2 app and its closed source remain unchanged.

The inspected owner is `CaptureCoordinator.chooseSource/start/pause/resume/stop`,
with `ScreenRecording` in `Services/RecordingCompletion.swift`. Its public
ScreenCaptureKit picker excludes Framelet itself. Camera/microphone/system
audio default off. The default UI hides the library while recording, so the
native menu-bar controls are part of the intended user path.

Prepare a separate bounded native FUI03 scope after the current release closes:

1. In a fresh disposable public Mac VM, launch a task-owned AppKit fixture app
   showing only authored red/blue content and a non-sensitive timing marker in
   one specifically titled window. Admit an absent nonce/inode-owned Framelet
   library and exact scratch/fixture bundle identities. No personal Mac,
   account, real user window, camera, microphone or system audio is included.
2. Launch the actual recorder. Use the normal content-sharing picker to select
   only that authored window; verify all audio/camera options remain off. A
   normal OS consent prompt may be handled only within that exact disposable
   window scope. Never alter TCC databases, grant broad filesystem access,
   bypass a refusal, or substitute full-display capture when window selection
   fails. Preserve unsupported/denied results as such.
3. Record two short takes, with a deliberate paused interval and an authored
   colour change while paused. Exercise native menu-bar Pause/Resume/Stop when
   the library is minimized. Wait for acknowledged finalization/ready state;
   reopen and export through the real save panel. Keep a finite recording/
   execution deadline and a concrete expected single-project/two-segment scope.
4. Independently inspect actual SCRecordingOutput MP4s, saved manifest, ordered
   clips, no unintended audio/camera tracks, readable decoded red/blue frames,
   export geometry/duration and pause-gap omission. Preserve original source
   hashes before/after export. Retain native summary, UI PNG/AX, complete command
   streams and bounded authored media; do not replay FUI01, FUI02 or old cases.
5. Teardown must request Stop through the app and establish ready/no unfinished
   writer before ordinary termination or owned-library removal. Do not reuse
   the non-capture controller's unconditional process reaping for an unfinished
   recording. If Stop cannot be acknowledged, keep the result failed, preserve
   partial media and report cleanup unverified; do not erase a live recording
   to obtain a passing teardown. Retire only the task's exact temporary control.

Materialize the fixture, native case, limits and failure/retention controller
before execution. Use at most one fixed public Mac job capped at 20 minutes per
changed candidate, no local environment/build/app under the failed Storage
Guard, no new dependency/service, paid enrollment, external message or model
call. A VM limitation must not be hidden by swapping in generated input movies.

Use the observed standard public Intel VM/Xcode 16.4 profile initially, with its
own exact source/architecture boundary. Foreground Recording-menu Pause/Resume/
Stop commands have observed native labels and remain usable with the library
minimized. The case must expose them through normal menus, acknowledge phase
changes, preserve the deliberate pause and restore/reopen/export normally.
Keep a teardown attachment even after an assertion: whether Start was requested,
whether Stop was requested, whether ready plus enabled source controls were
observed (the public no-unfinished-capture guard), and the corresponding uptime.
The controller must require that actual acknowledgment before termination or
library/scratch removal. If absent, preserve partial bytes and a failed/unverified
cleanup result; never replace it with a process signal or manifest-only guess.

`Tests/ci/CapturedWindowFiles.swift` now prepares the independent read-only file
verifier; it has only been syntax parsed, not built or executed. Compile it with
the existing core source files, like the earlier host-owned fixture helper.
Its snapshot mode waits at most 120 seconds for one ready two-take package,
then hashes original media/manifest with the same Swift system-uptime clock as
the future UI case. The controller must start this owned observer before the
native journey and retain its result before Export. The UI must wait five
seconds after Ready before requesting Export; an actual baseline timestamp
strictly before that action is required, not inferred from the delay. The
verification mode requires that exact baseline and original UI uptime JSON,
unchanged original/manifest hashes, two ordered full-take clips, audio/camera
off, no extra files/tracks, original geometry/durations, red then blue decoded
frames and a landscape export with the exact concatenated video duration.
The paused interval must be at least four seconds and excluded from the outer
capture-time bound. These are draft constraints; no native capture case or
safe recording controller is activated by adding this helper. A failed snapshot
or file check must stay failed, with its partial media retained. The first
encoded-sample timing contract remains explicitly unmeasured by this verifier.

This would prove the basic real screen-window path only. The correspondence of
the first `.complete` screen callback to the first encoded sample remains a
separate measured timing requirement; no camera/PiP synchronization inference
comes from silent window capture. Physical camera/audio, human accessibility,
multi-monitor/rotated displays, old-install migration and trusted downloaded-app
launch remain explicit additional gates. Do not claim full recorder or portfolio
completion from this draft or a narrower green check.
