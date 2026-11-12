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

Source-review correction after scheduling candidate 1: `RecordingLibrary.init`
creates the empty `Recordings` directory. The first immutable controller's
postcheck incorrectly allowed only the owner marker; its original execution
and verdict must remain unchanged. A corrected controller allows exactly the
marker plus that empty nonsymlink directory. This is a file-check correction,
not permission, app-source or capture expansion. Do not launch another native
job merely to replay an already observed UI phase; inspect and preserve the
first run's actual native/file/cleanup boundaries before choosing further work.

## Conditional candidate 2: Intel VM

Prepared while candidate 1 remains queued. **Do not activate concurrently.**
Only after candidate 1 is terminal, never allocated, and its exact control is
retired by the [conditional helper](picker-allocation-checks.md), candidate 2
may execute the same unexecuted FUI03A body once on the standard public
`macos-15-intel` runner. If candidate 1 does execute, review its originals first;
this alternative stays inactive until there is an evidence-backed reason.

The profile explicitly changes to x86_64/macOS 15 Debug, Xcode 16.4; it does not
claim ARM64 execution or replay the closed ARM64 FUI01/FUI02 cases. GitHub's
[standard runner labels](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
and [Intel image/toolchain list](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)
confirm this is an available public VM with Xcode 16.4. Availability/allocation
and actual toolchain must still be observed. No larger/paid runner is selected.

The updated fixed branch/template/controller select only candidate 2, include
the corrected empty-Recordings postcheck, unambiguous fixture action selectors
and before/after fixture inode binding. Its current-source guard compares
unchanged shipping inputs and the exact FUI03A body to
`7a0cd7f8e1dd338f3cf43f017a6fb1259d293c04` (reachable within the shallow source
checkout). The original candidate remains immutable at `97036fc9864dafe183d3d2500a919512d08678df`.
Same authored/no-Start scope, screenshots, file bounds, ordinary no-writer
teardown, 20-minute job cap, failure retention and exact self-retirement apply.
