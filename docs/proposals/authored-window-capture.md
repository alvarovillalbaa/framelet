# Next recorder requirement: actual authored-window capture

Draft dependency scope, 12 November 2026. FUI02 and its downloadable 0.1.2
preview have closed. The separate [picker readiness probe](picker-readiness-checks.md)
first materializes the authored fixture and observes native presentation/cancel;
it never selects a source or starts capture. The original [recorder contract](../specs/recorder.md)
requires actual capture/pause/resume/export proof; the existing authored-media
edit/export, window and packaging profiles do not supply it.

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

This would prove the basic real screen-window path only. The correspondence of
the first `.complete` screen callback to the first encoded sample remains a
separate measured timing requirement; no camera/PiP synchronization inference
comes from silent window capture. Physical camera/audio, human accessibility,
multi-monitor/rotated displays, old-install migration and trusted downloaded-app
launch remain explicit additional gates. Do not claim full recorder or portfolio
completion from this draft or a narrower green check.
