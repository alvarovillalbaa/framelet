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

The active workflow is confined to `qa/ordered-playback`; local `main` has no
active workflow. It must be removed after the focused acceptance run. Preserve
terminal failures and actual native output before claiming success. Local
builds remain stopped by Storage Guard; no app, capture, device access or UI has
been invoked by this work.
