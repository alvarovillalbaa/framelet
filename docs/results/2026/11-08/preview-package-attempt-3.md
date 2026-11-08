# Universal Release preview packaging — passed

8 November 2026. [Run 42470246801](https://github.com/alvarovillalbaa/framelet/actions/runs/42470246801),
job `128699096316`, passed at source
`161214ab3d34314ecf9a52a5a2aef79e502a8480` under workflow
`784d7adb80e5ce862905a600b8d7fe4ada0dd080`.

## Actual build and archive

Both sequential native SwiftPM Release builds completed: arm64 and x86_64,
with distinct scratch paths, matching binary-path queries and local loader
rpath disabled. `lipo` combined those actual binaries into the staged app;
the shared builder copied the source plist/icon and signed the full bundle
ad-hoc before creating the metadata-preserving ZIP/checksum. No architecture
fallback, app launch, capture, permission prompt or test execution occurred.

All **18 commands exited zero**, with 36 complete original stdout/stderr
streams. Toolchain: macOS 15.8.2 / arm64 host, Xcode 16.4 build 16F6, Swift
6.1.2 and macOS SDK 15.5. Both executable slices declare minimum macOS 15.0;
per-slice linked-library and runtime-search-path inspections passed. The
source plist declares version 0.1.0/build 1 and the expected bundle identity.
Native strict signature verification passed for all architectures before
archiving and after fresh `ditto` extraction. The seal is ad-hoc with no team
identity; this is not Developer ID trust or notarization proof.

The source/index/body/mode vector binds 66 files / 524,404 bytes. Of the old
38 sealed inputs, 37 remain unchanged; only the builder intentionally changes.
The earlier 30-case debug/ARM64 evidence retains its source/profile and was not
rerun or relabeled as executing this new universal Release binary.

The extracted bundle matched all four payload files and five directories,
their exact bytes/modes and observed attributes. All actual attribute maps were
empty; this is not a nonempty resource-fork/quarantine preservation experiment.
The archive contains no recording, test media, build cache, source history or
external framework. Its executable is 4,304,576 bytes, SHA-256
`eac8e0fefe34ee08b04002b3789e3a1a21e1f0ab6803a2ed518614778efbfdfe`.

Independent data-only review rehashed all 39 captures (36 command streams and
three assets), the 66 native source blobs/tree and both preserved failures.
The ZIP has nine members / 4,345,735 expanded payload bytes. Both raw Mach-O
slices have valid bounds, 58 load commands, macOS 15.0 targets, 41 system-linked
libraries each and no LC_RPATH. Both CodeDirectories have ad-hoc flags and no
team offset; all 1,030 SHA-256 code pages and six special slots were verified
independently. This inspected bytes in memory, without launching or installing
the app or invoking local native tools. It does not establish developer trust
or runtime behavior.

| Unchanged retained asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `Framelet-0.1.0-macos-universal.zip` | 1,157,438 | `c84865b23c93113114f44d7cbff17f19ca661905f2a1ca0f8f18a2b02ef1e76a` |
| `Framelet-0.1.0-macos-universal.zip.sha256` | 101 | `1435dfc7a21632d75242cdc0a87c0ed226cafb40e0c0ac2907ad824e94fc6ffa` |
| `Framelet-preview-manifest.json` | 1,735 | `3f899233af08cb19567100fa9a0cd5c47d7d652bf8f8f3ac957771a6b29750f2` |

## Ownership and proof limits

Controller elapsed: 49.919 seconds. Sampled peaks: 198,324,602 bytes owned
storage, 686,129,152 bytes attributed-child RSS and five processes. Cleanup
verified removal of 637 entries, absent owned root, zero attributed processes
remaining and no owned signals. Attribution covers tracked children, owner
markers and process groups; unrelated Apple/Xcode services are outside it.
The final 637-entry cleanup inventory is retained as a digest, rather than a
reconstructable full inventory; RSS is sampled, without an address-space limit.
Both prior failures were pinned/imported only, with zero packaging acceptance.
Attempt 1's teardown remains unverified; attempt 2's verified cleanup and
unproven internal Xcode crash remain unchanged.

Workflow `411036460` is disabled and QA3 retired at
`daf42621543c9ea8e71e5b2f6e14a62d1ee2735e`; the older completed workflow is
separately disabled. No active workflow exists in main. The
[distribution guide](../../../distribution.md) owns installation and trust
limits. Publish only the exact retained assets as `v0.1.0-preview.1`.

| Immutable original | Bytes | SHA-256 |
| --- | ---: | --- |
| [Receipt](preview-package-attempt-3.json) | 1,570,486 | `1438a7f6705f6cf74b1b9d0f19fec41c2cb94323c3a111cd1f354978fdd0e17e` |
| [Full job log](preview-package-attempt-3.log) | 1,587,505 | `4cfd538c13bdb6eedcccdf21ba27f3f5f2106aa8f7cb1deb0bda12bd90f24b59` |

Native UI/accessibility, live screen/window capture and permissions, camera/
audio synchronization, real export playback, a fresh Mac/downloaded-app launch,
Gatekeeper trust, Developer ID/notarization and full-product acceptance remain
open. No local app/build/test/native-library execution, model/provider call,
new account, paid enrollment or cloud service was used.
