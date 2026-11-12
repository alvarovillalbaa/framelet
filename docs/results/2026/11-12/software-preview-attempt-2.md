# Topology sampler stopped compilation; streams and fixture retained

12 November 2026. [Run 43261428207](https://github.com/alvarovillalbaa/framelet/actions/runs/43261428207),
job `131333462800`, failed at source `a9e7d6a6c123ca1e0abf782b5951265aa1349dc4`.
Native head `50e5f42fce49ee84bc8691d4352640ed920ed40b` matches tree
`fcbae2e1e0a40ad0d0a475e6e7500c93e7675ff8`. Product/verifier inputs match
the first software candidate. No compositor/verifier or pixel case ran.

The storage sampler's combined entry-count/no-symlink assertion failed during
core compilation, before it recorded topology. It also enforced that same
assertion during cleanup despite `enforce=False`. Exact offending paths/count
are unknown; do not invent them. The owned Swift driver (UID 501) was ordinarily
stopped with SIGTERM and its complete original streams retained. Cleanup then
tried signalling an exited Git child: actual process metadata shows `(git)` and
then `<defunct>` PID/group `1375`, UID 501; the signal was denied. Source-after/
index and owned-root cleanup remain unverified. This is not a pixel verdict.

All seven command records/fourteen original complete EOF streams were
independently decoded and byte/hash checked, including the aborted compile and
cleanup read. Cleanup read's final exit is unknown. Only the initial 507-file
source vector exists. Independent fixture cleanup succeeded: all three copied
inputs stayed byte-identical and their exact bytes are retained inline.
Last recorded sizes were 246,347 apparent/282,624 allocated bytes, not a verified
post-compile peak. Elapsed 6.637 seconds. No app/device/capture/export/old-case
execution or paid/model call.

Candidate 3 records file kinds, links/targets and failing counts/sizes before
refusal. Permit only compiler cache/temp aliases into the same owned cache/temp
or the active fixed Xcode Developer tree; never follow aliases for owned-size
accounting or accept links in source/fixture inputs. Other aliases/entry kinds
and all unchanged count/4-GiB limits still fail. Cleanup metadata observation
does not rethrow the work-admission failure. Wait/reap exited children, refresh
the original child status immediately before any signal and retain all errors.
No denied signal is retried or rights granted. Shipping/verifier inputs stay
exact, guarded against this measured source.

[Raw receipt](software-preview-attempt-2.json): 220,917 bytes, SHA-256
`265ff1a7de4f7abcd0c57482655d45688f9b502f766862057d9775a19dc4a091`.
[Lossless log](software-preview-attempt-2.log.json) preserves the sampler and
zombie/process observations. Artifact `13962609809`: 94,641 bytes, SHA-256
`24c5b21f15162816d08d9b7f10f013455b492bd0cabe439e0a32eb5519408a33`.
[Retirement](software-preview-attempt-2-retirement.json) passed: eight API calls/
16 streams verified, uploaded scratch removed, workflow `416275870` observed
disabled and exact head `9027d48ec995af6a6d50e20e0317e07a714232ce` deleted.
Its exact ref was independently absent; missing native-root proof stays missing.
