# Inactive Framelet native compile and core checks

Last updated: 2026-10-27

The [workflow example](native-checks-ci.yml.example) is inactive outside `.github/workflows`. No native build, test execution, app launch, device enumeration, permission prompt, capture or signing has been performed. The supplied AGENTS.md §14 requires explicit approval for temporary CI; local builds are blocked by the workspace Storage Guard reserve. This reviewable job includes native compilation, core tests and local ad-hoc packaging/signature verification, following the repository's [execution rules](../../AGENTS.md). No dependency installation, provider, paid plan, account enrollment or production configuration is proposed.

After approval, copy this reviewed workflow only to `.github/workflows/native-acceptance.yml` on the exact temporary branch `qa/native-acceptance` in the public personal repository `alvarovillalbaa/framelet`. Remove the active workflow afterward. Log the immutable source SHA and inspect every outcome. Source/case/tool changes require re-review. No other project's browser, backend or native approval authorizes this job.

## Exact scope

1. Read the installed toolchain/SDK and source digests. Refuse SDK below 15, a changed arm64 runner, any external package declaration, changed test count or pre-existing output.
2. Run `./script/build_and_run.sh --build-only`: compile the SwiftPM executable, stage a real `.app` with the checked-in Info.plist and apply/verify a **local ad-hoc** signature. Do not launch the bundle or raw executable. This does not use a certificate, Developer ID account, provisioning profile, notarization service, keychain secret or paid enrollment.
3. Run only the eighteen authored core XCTest cases (thirteen `RecordingTimelineTests` and five `RecordingCompletionTests`), with no retries. The xUnit report must contain exactly eighteen unique cases without failure, error or skip. The tests use in-memory values, JSON and asynchronous acknowledgement latches; they do not import or call the capture, camera, library or export services.
4. Verify packaged metadata and that the executable exists; ensure tracked product/test bytes remain unchanged.
5. Always remove only this fresh checkout's reproducible `.build`, `.swiftpm`, `dist` and owned test report. No test recordings or user library are created. No artifact/cache is uploaded, retained, released or attached to a publication.

The job uses one standard `macos-15` arm64 GitHub-hosted runner, twenty-minute deadline, read-only contents permission and a pinned checkout action with persisted credentials disabled. No custom/larger/self-hosted runner, secret, deployment environment, account token or artifact service is referenced. [GitHub's runner table](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job) currently lists that standard label as arm64, and [GitHub billing guidance](https://docs.github.com/en/actions/concepts/billing-and-usage) documents standard public-repository runner use as free. These primary sources were read on 2026-10-27; they do not establish unrelated account usage or future pricing.

No real media, screens, windows, microphone, camera, browser, UI automation, native TCC prompt or settings change is in this scope. The app is compiled and packaged, then only the separate core test executable runs. OS frameworks, SwiftPM and the installed toolchain may perform their normal build operations; this is not a claim of a general network sandbox. There are no external Swift package dependencies to resolve.

## What a pass would prove

Native source compiles/links for the logged runner SDK and architecture, packaging metadata/ad-hoc signature verifies, and the eighteen core cases pass. The tests cover ordering/duplicate clips, pause-gap omission, positive/negative/absent camera overlaps, invalid timing, trim/path/identity validation, canvas bounds, empty recovery, JSON round-tripping, early/late acknowledgements, independent waiters, cancellation and timeout isolation, and retained delegate failures.

It would **not** prove screen/window selection, permission refusal/recovery, capture start/pause/resume/stop, crash finalization, audio quality/mixing, camera synchronization, real export geometry/playback, UI interaction/accessibility, clean-machine installation, Developer ID signing, notarization or store distribution. Those remain separate acceptance work against the [product contract](../specs/recorder.md). Compile success cannot close the complete project goal.
