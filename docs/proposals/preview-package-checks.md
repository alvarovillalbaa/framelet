# Universal preview distribution

8 November 2026. Standing owner instructions to finish and publish every project,
“I approve everything”, “Keep going” and “Do all the work” authorize this free
build/package/GitHub-preview scope. No new confirmation is needed for it.

Framelet's existing source build and 30 focused native cases are closed at
`59b3c30d13f10c5e624c3abf717e71a04a173ba6`. Current clean main
`7188847d6657eed67212e719aad445d0a27fc096` contains no downloadable app release.
This scope supplies the missing preview archive; it does not claim capture or
trusted distribution acceptance.

Add an explicit `--build-preview` mode to the existing builder. It must refuse
a running app without quitting it, preserve ordinary modes, compile a Release
binary for arm64 and x86_64, reuse existing metadata/icon/bundle/ad-hoc signing,
and publish ZIP/checksum leaves exclusively. Preserve previous output on
failure. Do not change app source, resources, package dependencies or permissions.

Run one temporary public `macos-15` job capped at 20 minutes, fixed reviewed
source and `qa/framelet-preview-20261108-1`. Its push-only workflow checks out
the exact preparation commit. No arbitrary dispatch input or default active
workflow. Retire the QA control and disable/remove temporary CI after terminal
evidence. Preserve failed attempts before a changed candidate.

Use a private owned export of tracked Package/Sources/Tests/Resources/scripts
and license. Tests are included only because SwiftPM validates declared target
directories; do not run `swift test` or repeat the 30 accepted cases. Keep HOME
intact and task caches/builds/temporary files within the owned export/root.
Record the full native source/index/body/mode vector and toolchain/SDK versions.
No dependency install, third-party package, account, payment or app launch.

Verify actual plist identity/version/minimum macOS 15.0, exact supplied icon,
both executable architectures and deployment targets, ad-hoc signature without
a trusted signing identity, system-linked runtime dependencies and bounded
bundle/archive contents. Extract the actual ZIP into a fresh owned directory;
compare all bundle payload bytes/modes and verify its signature again. Never
run Framelet, enumerate capture sources, prompt for permissions, access a
camera/microphone or capture media. No physical-device/runtime inference.

Bound the ZIP to 8 MiB, expanded bundle to 32 MiB and members to 512. Retain
complete bounded command originals, actual ZIP/checksum/distribution manifest,
source/artifact hashes and finite cleanup evidence. Track owned children/groups,
stop them on timeout/interruption and verify their absence before removing
only task-owned output. A late cleanup failure must keep the result failed.

Publish the unchanged checked ZIP, checksum and manifest as GitHub prerelease
`v0.1.0-preview.1`. Verify uploaded bytes/digests and the exact source tag before
publication. Internal app version remains 0.1.0/build 1. No Apple Developer ID,
notarization, store submission, new hosted service or registry is proposed.

The new Release/universal packaging profile is separate from the earlier
ARM64/debug 30-case run. Of its 38 original build inputs, 37 remain unchanged;
only the intentional builder extension changes. Old tests are not relabeled
as executing either slice of the new archive.

Storage Guard currently reports 9.9 GiB free against 34.0 GiB required. No local
build/install/app/test/CLI/capture exception exists. Local work is source editing,
static Bash/Python checks and bounded evidence/archive inspection only. The
[distribution notes](../distribution.md) own user-facing limits and installation.
