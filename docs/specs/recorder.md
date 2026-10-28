# Framelet recorder contract

Last updated: 2026-10-28

The [personal project queue](https://app.notion.com/p/311a1ee8bd06805caa21c5306dd315ac), fetched on 2026-10-27, explicitly requests “desktop app for screen recording (locally-hosted app for macbook that substitutes Tella and other most popular screen recording apps”. No prerequisite attaches to this New-list entry. Three unknown embeds elsewhere make the parent fetch globally truncated; this is a bounded entry interpretation, not an exhaustive queue audit. No separate child brief was found. Framelet is a working product name chosen for this implementation.

## Product outcome

A native macOS 15+ recorder that lets a person choose their display/window, optionally include camera and independent system/microphone audio, record with a countdown, pause/resume, and stop into a recoverable local library. They can play recordings, trim/reorder/duplicate/remove clips without deleting source media, choose landscape/portrait/square canvas and screen/PiP/side-by-side layout, and export a new MP4. Recording packages and originals stay local. No account, paid provider, hosted database, telemetry, or network service is required.

SwiftPM uses only system frameworks. The primary WindowGroup has a native sidebar/detail editor; a MenuBarExtra exposes pause/resume/stop and a separate Settings scene owns defaults. Foreground keyboard shortcuts are labelled as such. A script builds a real `.app` bundle; a raw SwiftPM GUI executable is not the launch path. Default capture is SDR/H.264, at most 1920×1080, 30 fps. Screen capture permissions and device access occur only after explicit user actions. Audio and camera default off. No runtime capture or permission prompt is authorized as an incidental development check.

## Cross-lane contract

`Sources/FrameletCore` owns Codable value types and pure validation/timeline/layout calculations. `RecordingProject` has a stable UUID, schema version, capture options, status, sealed segments, ordered clips, canvas settings and optional error. Package layout is `<UUID>.framelet/manifest.json` and `segments/<UUID>-screen.mp4` / `<UUID>-camera.mov`. All media paths are package-relative; traversal, symlinks and unrelated paths are rejected. Atomic manifest replacements never overwrite source media. Partial/unsealed files survive capture failures and are visible through Reveal in Finder. On launch, unfinished projects are displayed as interrupted; they are not automatically recorded or deleted.

Sealed segments use actual screen video duration. Required camera alignment is signed: first **written** camera frame's host time minus first **written** screen frame's host time. Convert sample PTS through each capture clock into `CMClockGetHostTimeClock`; never derive alignment from Date or asynchronous recording-start acknowledgements. Missing or invalid timing is an error, not an assumed zero. Camera sidecars contain video only; microphone/system audio come from ScreenCaptureKit. A segment becomes editable only after both recording finish delegates acknowledge valid files. Pause closes the segment; resume starts another. No paused interval is inserted into the edit timeline.

**Open timing proof:** the current ScreenCaptureKit implementation observes the first valid `.complete` screen sample as its anchor, following Apple's sample pattern. Attaching `SCRecordingOutput` before capture guarantees the first captured sample is written, but the inspected documentation does not explicitly equate first `.complete` with the first encoded video sample. The camera uses sample-accurate file output. Correct correspondence between the screen anchor and encoded timeline remains an unverified implementation assumption; measure it with authored capture/export before claiming synchronized PiP. If it differs, fix the anchor/writer mapping before closing this requirement. Pure offset tests cannot settle it.

Clips identify sealed segments and finite `0 ≤ trimStart < trimEnd ≤ segmentDuration` ranges. Ordered clips concatenate, and edits leave original files intact. The core computes camera overlap in segment coordinates, correctly handling negative offsets, late starts, trims and absent camera. Normalized layout rectangles use a top-left origin. The exporter converts coordinates centrally, respects each video track's preferred transform, fits screen content and fills camera content without stretching, and carries every source audio track into the composition. Output is staged at a new destination and never replaces an existing file. Cancel/failure removes only the operation's owned staging output and retains project sources.

Playback defaults to the whole ordered recording. A shared composition builder
assembles the same clip ranges, canvas instructions, camera gaps and audio mix
for preview and export; preview retains its source assets and writes no media.
The global cursor seeks through clip boundaries. Selected Clip remains a
separate audition scope. A project/edit/canvas/scope change clears the old
snapshot and never automatically resumes playback. Capture suspension clears
the item and invalidates pending loads. Load, status and seek callbacks must
belong to the current generation/item; failed seeks or media expose an explicit
Reload Preview action. Original media and the existing screen-anchor timing
assumption are unaffected by this source change. Native playback/export proof
is still required.

## Integration interfaces

`@MainActor @Observable RecordingLibrary`: `projects`, `errorMessage`, `unreadableCount`, `baseURL`; `refresh()`, `create(options:) throws -> RecordingProject`, `save(_:) throws`, `project(id:) -> RecordingProject?`, `packageURL(for:) -> URL`, `mediaURL(projectID:path:) throws -> URL`, `newMediaURL(projectID:path:) throws -> URL`, `rename(id:title:) throws`, `moveToTrash(id:) throws`. Existing media must be a regular non-symlink file. New output paths use the separate resolver, which validates the owned parent and rejects every existing leaf, including dangling symlinks; it does not require an output file to exist. Root owns implementation.

`@MainActor @Observable CaptureCoordinator`: initialized with `RecordingLibrary`; `phase: CapturePhase`, `options: CaptureOptions`, `selectedSourceName: String?`, `projectID: UUID?`, `elapsedSeconds: Double`, `countdownRemaining: Int`, `errorMessage: String?`, `cameraSession: AVCaptureSession?`, readonly `hasUnfinishedCapture: Bool`; `chooseSource()`, `start() async`, `pause() async`, `resume() async`, `stop() async`, `clearError()`. `CapturePhase` cases: idle, choosing, countdown, starting, recording, pausing, paused, stopping, failed; selection never automatically starts capture. A failed phase is not shutdown acknowledgement: retain unfinished stream/delegate handles, block new capture, and allow Stop retry until shutdown is confirmed. Quit/edit/trash guards use `hasUnfinishedCapture`. Capture lane owns coordinator, stream/file delegates and camera service.

`@MainActor @Observable ExportCoordinator`: `isExporting`, `progress`, `errorMessage`, `outputURL`; `export(project:packageURL:destinationURL:) async`, `cancel()`. Export lane owns composition/export and its owned temporary files. Reject export while a project is recording/paused, and reject unreadable/missing/unsafe source files. Caller retains originals.

UI lane owns `FrameletApp`, Views, Settings and menu commands. It uses the above exact models/interfaces. It prompts before moving a selected package to Trash, blocks editing/removal of an active capture, and does not add account, service, or implementation details to the product flow. Capture is stopped/finalized or termination is cancelled before the app quits; closing a window does not silently orphan recording.

## Acceptance still required

Source/syntax review cannot prove native compilation, permission handling, real capture, audio quality, camera synchronization, pause fidelity, export playback, UI accessibility, crash recovery, signing, or notarization. A compile-only temporary macOS CI proposal is prepared separately and remains inactive until explicit approval. Real capture checks need an authored disposable window and an explicit bounded permission/data scope. No real user screen/device content is to be captured for testing by default.

The brief does not explicitly define cloud sharing, captions, transcription, AI editing, HDR/4K or a store release. These are not claimed features. Region selection and custom drawn camera masks are not yet implemented; the source uses native display/window selection and rectangular PiP. Full Tella feature parity is not established by the core recorder flow. Keep the overall project goal open until its actual source, build, capture/edit/export, publication and distribution boundaries have been verified.
