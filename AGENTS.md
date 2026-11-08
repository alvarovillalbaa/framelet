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
