# Sparse compilation-cache files identified before native execution

12 November 2026. [Run 43239027602](https://github.com/alvarovillalbaa/framelet/actions/runs/43239027602),
job `131254076926`, failed at source `4afda39b954b8416127f1619e0d94e9285a7d243`.
Native head `d70f0f06ba86f0b2804ae909cf393b07f877f60f` has the exact tree
`989a4faa069523137c9cf15a12a777c85c276a09`. No app/native case launched.
The 4 GiB apparent-size guard stopped the harness build; it is not a playback
failure. Preserve both failed attempts and their different proof boundaries.

The changed sampler retained the actual refusal: 26,961,393,387 logical bytes,
129,843,200 allocated bytes, 530 entries/435 unique regular files. Xcode 16.4
had created these task-owned files under
`derived/CompilationCache.noindex/generic/v1.1/`:

| File | Logical size | Allocated at refusal |
| --- | ---: | ---: |
| v8.data | 17,179,869,184 bytes (16 GiB) | 0 |
| v8.index | 8,589,934,592 bytes (8 GiB) | 0 |
| v3.actions | 1,073,741,824 bytes (1 GiB) | 0 |

All three were regular files with one link and distinct observed inode IDs.
The cleanup sample then showed only 4,096/12,288/12,288 allocated bytes for
those same files. This identifies sparse compiler-cache preallocation rather
than 25 GiB of physical payload. It supports a new, explicit task-scoped
allowance for exactly these three paths and measured maximum logical sizes,
with the whole tree still capped at 4 GiB of unique allocated blocks and all
other files still capped at 4 GiB apparent size. No product/cache-setting or
runtime assertion change is required. Total namespace would be capped at
29 GiB and 32,768 entries; no general large/sparse-file exception is inferred.

All eleven command invocations/22 streams were retained through EOF and
independently decoded and byte/hash checked. The build was explicitly stopped
with exit `-9` by the non-writer control; its stdout and stop/signal metadata
are original aborted-invocation evidence, not a completed build. The new pixel
verifier compiled, but no UI harness or runtime verdict follows.

Both 399-file source vectors and the index match. Released bundle, manifest,
two captured originals and the ownership marker stayed unchanged. Safe
no-native cleanup found one exact task-root `clang-stat-cache` worker, issued
ordinary termination after PID/command recheck and verified it absent. Owned
app/runner, library and root cleanup passed. Attempt 1's missing stream/root
proof remains missing; this result does not repair or replace it.

[Receipt](release-playback-attempt-2.json) SHA-256:
`96312e085eb7d4d98bc2e088f6df430ff90c69ac9e2c8559fc23113b32e9b774`.
The [lossless job log](release-playback-attempt-2.log.json), four original
authored input bytes and complete storage topology remain retained. Artifact
`13953528294` is 180,320 bytes, SHA-256
`cbb53acc0a561f2e70d31559bdf56bb745df9b9ec8d268a6fb2e78e93fba7cc4`.
[Retirement](release-playback-attempt-2-retirement.json) verified its upload,
removed uploaded evidence scratch, disabled workflow `416133365` and removed
unchanged QA head `a5519548ad1eeb7c8a84420fc58b897b9166b80f`; the exact ref
was independently observed absent. Local Guard refusal remains in force.
