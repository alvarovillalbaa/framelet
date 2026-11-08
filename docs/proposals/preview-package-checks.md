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

## Changed metadata control 2

The [first invocation](../results/2026/11-08/preview-package-attempt-1.md) failed
before any command/build because Mac Python lacks `os.listxattr`; its own
cleanup remains unverified. Preserve the exact originals and do not carry any
new packaging acceptance. QA2 uses `qa/framelet-preview-20261108-2`, directly
based on the first checked source, with the same builder and all application/
package/resource/test inputs unchanged.

Replace only metadata inspection with bounded read-only macOS `listxattr`/
`getxattr` calls through standard-library `ctypes` and the system libSystem.
Use exact native argument/return types, no-follow options, finite allocation
and errno/change refusals; no write/remove-attribute API or dependency. Preserve
actual attributes and quarantine data. Record the created owner/root identity
before its first snapshot so even an admission failure retains exact scope.
Run the whole new build/package/round-trip scope afresh under the same limits.

## Changed native build control 3

[Attempt 2](../results/2026/11-08/preview-package-attempt-2.md) verified native
metadata and owned cleanup, but the automatic Xcode build service crashed at
0% before Swift compilation. The internal cause is unknown. Preserve that
failure and change the build path rather than repeat it unchanged.

QA3 (`qa/framelet-preview-20261108-3`) uses two sequential single-architecture
SwiftPM Release builds with explicit `--build-system native` and separate
`.build/preview-arm64` / `.build/preview-x86_64` scratch paths. Query each actual
binary path with matching flags, then `lipo -create` directly into the owned
staged bundle. Keep the same universal macOS 15 target, source, signatures,
exclusive ZIP/checksum, metadata and full round-trip checks. App/resource/
package/old-test inputs remain unchanged. No partial architecture or weaker
acceptance replaces the original universal deliverable.

Use SwiftPM's `--disable-local-rpath` deployment option in the same preview-only
build/path flags. This app has no adjacent private dynamic libraries; suppress
the native engine's default `@loader_path` search path rather than weakening
the per-slice system-runtime checks. The
[official 6.1.2 linker implementation](https://github.com/swiftlang/swift-package-manager/blob/swift-6.1.2-RELEASE/Sources/Build/BuildDescription/ProductBuildDescription.swift#L247)
owns this option's effect. Actual linked libraries and search paths still need
fresh inspection; the flag alone supplies no runtime-compatibility proof.

The third source is based on the second checked commit; fetch four commits to
reach the original app-input base. Pin both prior originals and preserve their
zero packaging acceptance and distinct cleanup status. Run all new packaging
work afresh, with no old test rerun or new dependency/account/payment.
