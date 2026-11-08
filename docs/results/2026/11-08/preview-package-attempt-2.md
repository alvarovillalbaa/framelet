# Preview packaging attempt 2 — Xcode build service failed

8 November 2026. [Run 42469620595](https://github.com/alvarovillalbaa/framelet/actions/runs/42469620595),
job `128697106420`, executed source
`7f2f9864f15f8be1a2e0197bbdcdc8fe583b6ff6` under workflow
`b14ffd42075d5e92fa6b4d622b99320860280f16`.

The Mac-native read-only metadata interface worked. The source/index guard
bound 63 tracked files and revalidated the first attempt's exact originals and
60 native source blobs, explicitly importing its failure without acceptance.
Five tool observations exited zero: arm64 host, macOS 15.8.2, Xcode 16.4 /
16F6, Swift 6.1.2 (driver 1.120.5) and macOS SDK 15.5.

The sixth command, `./script/build_and_run.sh --build-preview`, exited **1**.
Its complete stdout reached Xcode's dependency graph/build description at 0%,
then reported: “The Xcode build system has crashed.” Stderr was empty. The
controller error is `command_failed_or_left_processes:preview-build`; the raw
exit status proves a failed build command. The internal service-crash cause
was not established. Do not infer a Swift source defect or retry unchanged
because the tool's text suggests building again.

No Swift compilation, app launch, capture, test, signed preview bundle, ZIP or
release acceptance was observed. All six commands retain complete original
stdout/stderr, including the failed build. The old 30 tests were not rerun.

**Owned cleanup passed:** 132 entries removed, root absent, zero attributed
processes remaining, 41 observed process identities / 23 groups and no owned
signals. Controller elapsed: 12.178 seconds; sampled peaks 1,749,670 bytes
scratch, 178,405,376 bytes RSS and seven owned processes. Scope excludes
unrelated Apple/Xcode services. This does not repair attempt 1's unverified
teardown.

Workflow `411036460` was disabled again and QA2 retired at
`81f118281086dad95ac4736cbd2d82cff18df166`. A changed builder may compile each
architecture separately with SwiftPM's native Release build system, in distinct
scratch directories, then combine the actual binaries with `lipo` before the
same bundle/signature/ZIP checks. The
[SwiftPM 6.1.2 option implementation](https://github.com/swiftlang/swift-package-manager/blob/swift-6.1.2-RELEASE/Sources/CoreCommands/Options.swift)
forces Xcode for multiple architectures in one call; separate single-architecture
calls preserve the requested native engine. This changes the observed failing
path while preserving universal arm64/x86_64 output; it is not a claim about
the service crash's internal cause. Full packaging must execute afresh.

| Immutable original | Bytes | SHA-256 |
| --- | ---: | --- |
| [Receipt](preview-package-attempt-2.json) | 19,582 | `20d5a210f028c7f5c8df54561e97249b4a50070d87c3acf968f46fa959c2164c` |
| [Full job log](preview-package-attempt-2.log) | 36,675 | `8e4e0671dc6ef26190caf55ecced4fc5a6caefe72ce8b738c34ae0e97131a27d` |

No local app/build/test/native-library execution, dependency upgrade, paid plan,
account, trusted signing, notarization or device access. Preserve both failed
attempts and their separate cleanup boundaries.
