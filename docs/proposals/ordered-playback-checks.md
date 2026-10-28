# Ordered recording playback acceptance

28 October 2026. Alvaro approved this exact scope under the supplied workspace
AGENTS.md §§7 and 14. [Actual attempts](../results/2026/10-28/ordered-playback-checks.md)
record execution and remaining proof. The earlier Framelet compile proposal or
another app's approval did not authorize it.

## Scope

Use the [inactive workflow](ordered-playback-ci.yml.example) on only
`qa/ordered-playback`, in one public standard `macos-15` arm64 job capped at
20 minutes, with read-only contents permission and a pinned checkout action.
Require installed SDK 15 or later, record Swift/SDK/architecture/source identity,
and verify the [source seal](../results/2026/10-28/ordered-playback-source.json).
No external package dependency, secret, paid enrollment or larger runner is
included. Stop and re-review a changed architecture, case set or external
dependency.

1. Run the existing `script/build_and_run.sh --build-only` to compile and package
   the native app with a local ad-hoc signature. Verify metadata, executable and
   signature. Do not launch the app or its executable.
2. Run exactly **30 authored XCTest cases**, with no retries: the original 13
   `RecordingTimelineTests`, five `RecordingCompletionTests`, six new
   `RecordingCompositionTests` and six new `UIPlaybackModelTests`. The source
   seal lists every exact name; the xUnit result must match that complete set,
   with zero failures, errors, skips or duplicate cases.
   Use SwiftPM's XCTest runner with `--parallel --num-workers 1`, explicitly
   enabling XCTest and disabling the unused Swift Testing library. This runs
   one case worker at a time while producing the actual xUnit report; the
   pinned SwiftPM 6.1.2 serial path does not emit XCTest xUnit. Log the verified
   actual case identities and report hash before removing the report.
3. Verify tracked product/test bytes remain unchanged. Remove the temporary
   active workflow after the approved focused run. Preserve failures and exact
   source identities in the owning results receipt; bounded fixes and reruns of
   these same cases may follow failures. Broader cases or changed runtime
   resources require a new scope.

The composition cases use actual AVFoundation tracks, generated frame pixels
and video composition instructions to check ordering, trims, duplicate clips,
cross-boundary output, signed camera gaps, retained source files and cancelled
assembly. The player cases use actual muted AVPlayers to check loading the
ordered duration, global seeking, replay after the end, capture suspension,
obsolete callbacks and media failure/recovery. These do not replace native
framework classes with test doubles. The original eighteen core cases remain
authored in-memory validation/lifecycle checks.

Cancellation is probed at partial and final assembly progress. The obsolete-seek
case observes 200 ms of stable replacement state; it does not independently
acknowledge delivery of the old callback or exhaust scheduler interleavings.

## Disposable media and boundaries

The job creates one private `RUNNER_TEMP/framelet-playback-RUNID` root only after
confirming it and all task output paths are absent. Each fixture creates a fresh
UUID child and a custom local recording library inside it. It generates tiny
solid-colour video files with AVAssetWriter; these are authored media, never
screen, camera, microphone or user-library input. The model tests mute playback.
Each fixture removes only its owned child. The final cleanup runs only after a
successful ownership preflight and removes only that root, the exact report and
this fresh checkout's reproducible build outputs. Runner disposal is the final
boundary after an interrupted job. No media or build artifacts are uploaded.

No UI automation, app window, source picker, capture, device enumeration,
permission prompt, real user media, account, provider, model call, database,
network integration, production setting or signed distribution is included.
AVFoundation/SwiftPM perform their normal native operations; this is not a
general network sandbox. The test target imports the executable module for
testing through SwiftPM; it never constructs or starts the `@main` App.

Local Storage Guard reported **14.0 GiB free versus 34.0 GiB required** for the
estimated native operation. No local build, typecheck, media generation, test,
player, UI or app execution was attempted. Syntax parsing does not replace
these checks.

## What a pass would establish

The logged runner can compile/package the exact source, the eighteen existing
core cases pass, and the twelve synthetic native cases establish their specific
composition/player behavior. This does not establish real screen/window
capture, encoded-frame timing correspondence, camera/audio synchronization,
live audio quality, UI accessibility/interaction, native export playback,
clean-machine install, Developer ID signing, notarization or store release.
The [complete product contract](../specs/recorder.md) remains unfinished until
its separate acceptance boundaries have evidence.

Apple's [composition playback example](https://developer.apple.com/documentation/avfoundation/debugging-avfoundation-audio-mixes-compositions-and-video-compositions)
uses a player item with the editor's video composition and audio mix. Its
[transport guidance](https://developer.apple.com/documentation/avfoundation/controlling-the-transport-behavior-of-a-player)
describes observing item readiness. SwiftPM's
[target documentation](https://docs.swift.org/latest/documentation/packagedescription/target/)
and [command-line package example](https://www.swift.org/getting-started/cli-swiftpm/)
document in-package targets and a test target depending on an executable. These
primary contracts guide the source; they do not prove this implementation runs.
