# Framelet developer preview distribution

12 November 2026. The [0.1.2/build 3 developer preview is public](https://github.com/alvarovillalbaa/framelet/releases/tag/v0.1.2-preview.1).
Its new [universal Release build/ZIP round trip](results/2026/11-12/window-preview-attempt-1.md)
and [anonymous asset delivery](results/2026/11-12/window-preview-publication.md)
passed. Separate [native editing/reopen/export](results/2026/11-12/native-ui-attempt-9.md)
passed at its original source with authored silent media. The separate
[native window check](results/2026/11-12/window-sizing-attempt-3.md) qualified the
placement repair on a 1024×768 arm64/debug VM, covering first launch, relaunch,
an additional window and relaunch again. The Release package preserves those
FUI02-qualified runtime inputs, with version metadata updated.
Live capture, audio/camera timing, human accessibility, physical/multiple/rotated displays,
trusted distribution and fresh downloaded-app launch remain open.
The small-VM window-edge defect is fixed in this version. Old-install migration
is unverified. Both older previews and the failure-evidence archive remain unchanged.

## Preview contents and trust

The assets are `Framelet-0.1.2-macos-universal.zip`, its
`.zip.sha256` checksum and `Framelet-preview-manifest.json`. The ZIP contains
`Framelet.app`, version `0.1.2` / build `3`, requiring macOS 15 or later.
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

Obtain all three assets from the exact preview release linked above.
Compare the ZIP's SHA-256 with the published checksum and manifest:

```sh
shasum -a 256 Framelet-0.1.2-macos-universal.zip
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
retains its older debug ARM64 source/profile and was not replayed. The separate
FUI01 native journey qualifies actual UI editing and an authored silent-media
export at its own source. FUI02 then qualifies the changed window placement.
The new package preserves all 28 FUI02-qualified runtime/package/icon inputs;
version metadata and the matching builder guard intentionally change. It
builds/packages both Release slices without launching them or replaying either case.
This does not establish live capture or Release runtime on either architecture.

The [publication record](results/2026/11-12/window-preview-publication.json)
and [independent public readback](results/2026/11-12/window-preview-public-readback.json)
verify the exact tag, three server digests and anonymous downloaded bytes.
A fresh installation and downloaded-app launch were not performed.
