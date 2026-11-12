# Framelet developer preview distribution

12 November 2026. The [0.1.5/build6 developer preview is public](https://github.com/alvarovillalbaa/framelet/releases/tag/v0.1.5-preview.1).
[Both Release slices and fresh ZIP/signatures](results/2026/11-12/coverage-preview-attempt-1.md),
[full native playback/nine colors](results/2026/11-12/coverage-playback-attempt-1.md)
and [anonymous asset delivery](results/2026/11-12/coverage-preview-publication.md)
passed their separate scopes. The exact archive fixes the black Recording
preview caused by a final instruction ending before the native asset.

The complete playback journey covers pause/frozen cursor, continuous boundary,
seeks, Selected Clip reset, end/replay and normal Quit/reopen on an Intel VM,
with actual Release-only phase PIDs, original screenshots, unchanged source/
bundle/media and acknowledged cleanup. Earlier [editing/export](results/2026/11-12/native-ui-attempt-9.md),
[small-display placement](results/2026/11-12/window-sizing-attempt-3.md) and
[actual silent-window capture/export](results/2026/11-12/capture-attempt-4.md)
retain their own original sources; these were not replayed for 0.1.5.

The older 0.1.3/0.1.4 Recording failures and [raw failed packet](results/2026/11-12/compatible-packet-verification.md)
remain intact. The [causal experiment](results/2026/11-12/composition-properties-attempt-2.md)
and [direct product regression](results/2026/11-12/exact-coverage-attempt-1.md)
support the exact-duration repair. All 14 older assets / 6 tags were preserved
through publication. No routine replay/rebuild of closed scopes is needed.

ARM runtime, physical/multiple/rotated displays, real camera/audio synchronization,
encoded first-frame timing, old-install migration, human accessibility and trusted
downloaded-app launch remain open. This is an ad-hoc developer preview.

## Preview contents and trust

The assets are `Framelet-0.1.5-macos-universal.zip`, its `.zip.sha256`
checksum, `Framelet-preview-manifest.json` and `Framelet-playback-qualification.json`.
The unchanged build manifest records packaging-time checks; the separate playback
record captures the later full Release result. The ZIP contains `Framelet.app`,
version `0.1.5` / build `6`, requiring macOS 15 or later.
The executable must contain both `arm64` and `x86_64` slices. Apple's
[universal binary guidance](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
explains that these are separate compiled slices; their presence alone does
not establish runtime behavior on both architectures.

The preview uses local ad-hoc signing, `codesign --sign -`, without a paid
identity, certificate or Apple enrollment. Expect `Signature=adhoc` and no
`TeamIdentifier`; CI must retain the actual signature inspection. Apple's
[ad-hoc signature contract](https://developer.apple.com/documentation/security/seccodesignatureflags/adhoc?changes=_8)
states that this seal carries no signing identity. A valid seal detects changes;
it does not authenticate a developer or make this a Developer ID release.

This preview is **not notarized**. Apple's
[notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
describes the separate Developer ID and notary-ticket process. Default
Gatekeeper acceptance of a downloaded preview is not established; see Apple's
[macOS code-signing security model](https://support.apple.com/en-ca/guide/security/sec3ad8e6e53/web).

## Download and inspect

Obtain the ZIP, checksum and both verification records from the exact release linked above.
Compare the ZIP's SHA-256 with the published checksum and manifest:

```sh
shasum -a 256 Framelet-0.1.5-macos-universal.zip
```

Extract using Finder, then copy `Framelet.app` to Applications if desired.
Keep macOS protections enabled. If macOS refuses the downloaded app, stop;
use the source-build route below or wait for a trusted distribution release.
Downloading or extracting this preview does not grant recording permissions.

## Build the preview from source

Use a reviewed preview-tag checkout, macOS 15+, Python 3 (standard library
only), and a macOS 15+ SDK toolchain. [Swift's macOS installation guidance](https://www.swift.org/install/macos/)
points to Xcode for Apple-platform development. Run the workspace Storage
Guard first where configured; a failed reserve check remains a refusal.

```sh
./script/build_and_run.sh --build-preview
```

This mode must build/package only, without opening or quitting the app. It
uses separate SwiftPM native Release builds for arm64 and x86_64, combines the
two actual binaries with `lipo`, and emits the app, ZIP and checksum under
`dist/`. SwiftPM documents
[Release builds and binary paths](https://www.swift.org/documentation/server/guides/building.html);
its [official 6.1.2 option definitions](https://github.com/swiftlang/swift-package-manager/blob/swift-6.1.2-RELEASE/Sources/CoreCommands/Options.swift)
define native/single-architecture selection and separate scratch paths. A local source build remains an
ad-hoc development build and does not close the product acceptance gaps.

Preview flags also disable SwiftPM's local loader-path search entry; the
per-slice runtime-library inspection remains a separate packaging check.

## Packaging and evidence boundary

Follow Apple's [ZIP packaging guidance](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution).
The builder uses metadata-preserving `ditto` with `--keepParent` and
`--sequesterRsrc`; Apple's installed `ditto(1)` manual specifies resource-fork
and HFS metadata preservation in `__MACOSX`. Sign the complete bundle before
archiving; retain bundle-file hashes, modes and architecture/signature details
in the manifest. Fresh `ditto` extraction must preserve those files and pass
strict signature verification. Bounds are 8 MiB ZIP, 32 MiB expanded and 512
members; a packaging or cleanup failure remains visible.

The [accepted 30-case evidence](results/2026/10-29/ordered-playback-release.md)
retains its older Debug/ARM64 source and was not replayed. FUI01/FUI02/FUI03
retain their original editing/window/capture sources. The changed preview/builder
has its own direct product regression and complete 0.1.5 Release/Intel qualification.

[Publication](results/2026/11-12/coverage-preview-publication.md) verifies the
new tag, four server digests and four anonymous downloads. The3 package assets
are unchanged; the fourth record describes the later full playback result.
[Fresh public metadata](results/2026/11-12/coverage-preview-publication-readback.json)
independently confirms the release/tag/assets. These checks do not establish a
fresh downloaded-app launch, Gatekeeper acceptance or Apple silicon runtime.
