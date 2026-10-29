# Approved ordered-playback checks

28 October 2026. Alvaro explicitly approved the 30-case native/temporary-CI
scope at source `76e7ced4ecfc4fd147d07273f3490746ab69d4db`. Approval includes
bounded fixes and reruns of the same cases, without app launch or user/device
media. The original [proposal](../../../proposals/ordered-playback-checks.md)
defines the complete boundary.

## Attempts

1. [Run 40779669465](https://github.com/alvarovillalbaa/framelet/actions/runs/40779669465),
   activation `099279e1766a751694cc91c815560caee5b7cb46`: terminal workflow-file
   failure before any job or check-run was created. No native cases or build ran.
   The template incorrectly referenced `runner.temp` in job-level `env`.
   GitHub's [context availability contract](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#context-availability)
   excludes the runner context there. Fix `26c774e` computes and exports the
   canonical fixture root from the runner preflight through `GITHUB_ENV`, then
   creates it privately. The workflow example and seal were updated together;
   product and test source are unchanged.
2. [Run 40780096039](https://github.com/alvarovillalbaa/framelet/actions/runs/40780096039),
   checked branch `887cbd90498a3ed2f205ebbbdb31adf90371d82e`, job
   `123139298687`: terminal compilation failure after successful source/toolchain
   and disposable-ownership preflight. Runner macOS 15.7.9 arm64, Swift 6.1.2,
   SDK 15.5. All test and package-verification steps were skipped; final owned
   cleanup passed. No native case executed. The decoded job log SHA-256 is
   `85eee13aac623f9e16c1383494c444cea60327928f8ea09dfe058ff37a941132`.
   Compilation exposed the camera recorder's unsupported macOS `inputPriority`
   preset/protocol declarations and the selected-clip load's async seek call.
   Bounded source compatibility repairs preserve the capture timing contract
   and fence the awaited seek acknowledgement before continuing setup.
3. [Run 40781450459](https://github.com/alvarovillalbaa/framelet/actions/runs/40781450459),
   branch `60de8eee89658aae73f86b5b16eb6268159075b2`, job `123143874327`:
   native build and local ad-hoc packaging succeeded. XCTest executed all thirty
   selected cases with zero failures; each actual case has an individual pass
   record. The job then failed because the expected xUnit file was absent, so
   final package verification was skipped. Owned cleanup passed. Decoded log
   SHA-256: `d4a34e4733d7d68011c6eda97109454d1f44fc183281265d8245059a532a5759`.
   This is a test pass and a reporting failure, not a green acceptance job.
   Pinned [SwiftPM 6.1.2 source](https://github.com/swiftlang/swift-package-manager/blob/swift-6.1.2-RELEASE/Sources/Commands/SwiftTestCommand.swift#L284-L334)
   emits XCTest xUnit only through its parallel runner. The corrected invocation
   uses that path with exactly one worker, keeps the same thirty cases and all
   verdict checks, and disables the unused Swift Testing runner. It also logs
   actual XML-derived case identities and the XML hash before cleanup.
4. [Run 40783077968](https://github.com/alvarovillalbaa/framelet/actions/runs/40783077968),
   branch `735d0bcacdbdf97d47274e3cd09abecbb9be6f5b`, job `123149376063`:
   **success**. Native compile/package, all thirty cases, exact XML verdict,
   bundle metadata/ad-hoc signature, unchanged source and owned cleanup passed.
   Environment: macOS 15.7.9 arm64, Swift 6.1.2, SDK 15.5. The XML-derived
   record contains thirty unique passing cases, zero failures/errors/skips,
   5,012 XML bytes and SHA-256
   `7e99084a5cf940ac2f0644e92584f6860b7f39f700b465fd0b292fcd608c18f6`.
   Decoded log: 60,348 bytes, SHA-256
   `a35c60114d00ff136f8cf195a4c5f0880e2ee052f0dcb00719e05db270af8dc8`.
   Independent log review matched the actual XML-derived identities, all thirty
   numbered native cases, source hashes and success/cleanup markers. Raw XML
   was deliberately cleaned up; its digest was emitted by the in-job validator,
   not independently rehashed afterward.

The complete [machine-readable report](ordered-playback-checks.json) preserves
the exact cases, run/step identities, attempted failures, decoded-log hashes,
checked source seal and limitations. The accepted source is personal main
`59b3c30d13f10c5e624c3abf717e71a04a173ba6`, represented in CI by that commit's
equivalent tree plus the temporary workflow. Subsequent closure edits change
only documentation and evidence, with all thirty-eight build inputs unchanged.

On 29 October the active workflow was removed from `qa/ordered-playback` at
`104a7aa89eefc30fd55571b950dc3ce6e81769ab`. Recursive GitHub tree readback
confirmed no workflow files remain there. Personal `main` never gained an
active workflow. Source/runner logs establish the scoped native proof; app UI,
live capture, timing correspondence, audio quality, real export and trusted
distribution remain unverified. No app, capture, device access or UI was invoked.
