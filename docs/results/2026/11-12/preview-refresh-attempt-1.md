# Framelet 0.1.1 universal preview qualification — passed

12 November 2026. [Run 43195296022](https://github.com/alvarovillalbaa/framelet/actions/runs/43195296022),
job 131104577618, passed at source
`618cabda9b08b04604dbb7992e8c4f73ff9606a8` (tree
`80a19f81c00f1b8d047c0457138bb08604b8d4c1`). This new profile imports the
[closed FUI01 result](native-ui-attempt-9.md) without replaying it. The archived
0.1.0 controller, previous releases and all failed native originals are intact.

Both native SwiftPM Release builds completed, arm64 and x86_64, with separate
scratch paths; the builder combined and ad-hoc signed the actual slices.
Version 0.1.1/build 2, macOS 15.0 minimum targets, per-slice system links/search
paths, both-slice strict signature and empty entitlements passed. Fresh `ditto`
extraction matched all bundle bytes, modes and observed attributes, and its
signature verified again. Toolchain: macOS 15.8.2/arm64, Xcode 16.4/16F6,
Swift 6.1.2 and macOS SDK 15.5. No app or test launched in this profile.

Separate first-party AVFoundation inspection decoded the exact retained FUI01
export, SHA-256 `10a5753d036647e527b17fdf39e592bd2a4c0a22e4633e09b3e2a8d778e5d679`.
It reconfirmed 1.2 seconds, 1080×1080 and blue/red center samples. All four
corner regions at both 0.2 and 1.0 seconds decoded RGB `[240,232,210]`, within
the stated Sand colour/codec tolerance. No new export or UI replay occurred.

All 21 commands exited zero. Independent data-only review decoded/hash-checked
all 42 complete streams and three retained assets; the source vector matches
the 161-file / 19,501,151-byte native Git tree. All 28 qualified runtime/package/
icon inputs remain exact. Bundle version and the builder's matching filename/
guard are the only product-input changes from FUI01. An independent ZIP read
verified CRCs, nine members / 4,366,167 expanded bytes, all four payload hashes/
modes and two bounded Mach-O slices with arm64/x86_64 CPU identities.

| Retained asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `Framelet-0.1.1-macos-universal.zip` | 1,159,292 | `0a02be066db9936c35decab2b32e4892cbf1c75b97ed3d2188c0abc420a78fce` |
| `Framelet-0.1.1-macos-universal.zip.sha256` | 101 | `f7631379c8b09a575a5016967254336237cc85c18a6e9716cbb4be378edd57dc` |
| `Framelet-preview-manifest.json` | 2,617 | `a05a21480e2df7852911a09b16f6f4fc378f1d4901de2c4022eff164e6158bd5` |

The [complete receipt](preview-refresh-attempt-1.json),
[lossless job log](preview-refresh-attempt-1.log.json), and
[retirement receipt](preview-refresh-attempt-1-retirement.json) preserve originals.
Elapsed 134.845 seconds; sampled peaks were 262,957,514 owned storage bytes,
769,769,472 attributed-child RSS bytes and five processes. Cleanup removed
790 entries, verified the absent owned root and zero remaining owned processes,
with no owned signals. Attribution excludes unrelated Apple/Xcode services;
RSS is sampled and the final cleanup inventory is digest-only. Observed xattrs
were empty, so this is not a nonempty resource-fork/quarantine experiment.
Workflow 415824158 is disabled and the exact QA ref is independently absent.

The checked ZIP/checksum/manifest are ready for unchanged publication as
`v0.1.1-preview.1`; publication and anonymous delivery are separate proof.
The subsequent [publication and anonymous downloads](preview-refresh-publication.md)
passed for these exact retained assets.
This does not establish Release runtime on either architecture, fresh downloaded
app/Gatekeeper trust, live capture/permissions, physical camera/audio timing,
human accessibility or narrow-window layout. Existing native screenshots show
window-edge clipping on the 1024-pixel VM; that remains open. No local build,
app/test/native-library execution, model call, paid service or enrollment was
used. Do not rerun this accepted profile or the older thirty cases routinely.
