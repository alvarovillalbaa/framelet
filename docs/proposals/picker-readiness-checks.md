# Authored-window picker readiness — FUI03A

12 November 2026. The public 0.1.2 repair is closed. Alvaro's standing approval
of all work covers this concrete preparatory native/temporary-CI scope for
the separate [actual-window recording requirement](authored-window-capture.md).
The system picker's actual UI has not been observed. Qualify presentation and
cancellation with an owned fixture before materializing recording selectors.
This is not source-selection, capture, pause/resume or export acceptance.

One fresh public `macos-15`/ARM64 VM, Xcode 16.4, at most 20 minutes, runs only
`FrameletPickerReadiness/testFUI03APresentOwnedWindowPicker`. The existing native
Xcode target builds the unchanged app, with its empty production ad-hoc
entitlements and existing UI runner sandbox. No dependency, account, production
configuration, TCC edit, grant, prompt acceptance or capture fallback is used.
Do not replay FUI01, FUI02, playback/core tests or preview packaging.

The host controller admits the default Framelet library only when absent,
then binds it to a fresh nonce/inode. It compiles a separate AppKit fixture
bundle `com.alvarovillalbaa.FrameletAuthoredFixture`, ad-hoc signs it with empty
entitlements, and opens its sole titled 640×400 window. Its pixels, red/blue
buttons and quarter-second marker are authored. The title contains the nonce;
fixture bundle hashes and inode are retained. No input movie substitutes for
ScreenCaptureKit output, and no recording is attempted in this probe.

XCTest observes that exact fixture, the recorder's initial unselected/ready
state, disabled Start and camera/microphone/system-audio toggles off. It opens
Choose Source once, observes the choosing phase, retains actual screen PNGs
and app accessibility trees, then presses Escape and requires unselected/ready
state again. It never clicks a source, Share, Start or device/permission button.
At most sixteen running UI applications on this fresh VM supply only their
bundle/PID/state and accessibility trees for locating the system-owned picker.
This enumeration must not run on Alvaro's Mac. A failed/denied presentation or
cancellation stays failed; do not retry through permission settings or guesses.
Original images/trees require independent review before claiming visible picker
readiness, even if native assertions pass. An unobserved system UI remains open.

The bounded controller has a 15-minute work budget and per-command deadlines/
2 MiB streams; it exports only current build/test inputs, not repository history
or old evidence. It verifies the fixture unchanged and that no recording package
was created, then terminates only its owned recorder/UI runner/fixture paths.
This ordinary teardown is specific to this **no-Start** scope. It must never be
copied into an actual-capture case without Stop/finalization acknowledgment.
Preserve nonce/inode-bound library files, original PNG/AX/native summaries,
complete command streams and failures before removing owned resources. Inline
evidence is bounded at 8 MiB and the separately uploaded packet at 128 MiB.
Passing raw xcresult intermediates may be removed only after original exports
and all independent verdicts are retained. Failed bundles stay in the packet.
The final helper verifies the uploaded artifact's source/run/digest, removes
only its uploaded packet, disables its workflow and deletes its unchanged QA
head. No active workflow file is added to main.

Local Storage Guard now measures **6.1 GiB free / 34.0 GiB required**. No local
build, app, native test, recorder or environment installation is permitted.
Only source/XML/Python/Swift syntax and whitespace checks run locally. This
probe changes no shipping product code; existing qualified inputs must remain
byte-exact. Apple documents [single-window picker mode](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpickermode/singlewindow)
and [user-controlled content selection](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker/shared).
Neither API documentation nor this plan proves live capture or trusted
distribution. Materialize the full recording case and safe teardown separately
after the actual picker evidence is reviewed.
