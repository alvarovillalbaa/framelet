# 0.1.5 universal package passed; app qualification remains separate

The [bounded non-launching package](https://github.com/alvarovillalbaa/framelet/actions/runs/43296847217)
passed both native Release slices and fresh ZIP round-trip/signature checks.
Source `0b2a03c0ac3af3c8c5605a5b4858b1136b43ec4c`, native
`a3114a7782051322191fc7ce0df5ea3cd4c225e2`, matching tree
`c9a6b7719f3e6857d75f24695ee85e2d182961c3`; QA
`b60cb725e2e843299f950e35b7a3fa0addb34e2a`. Run43296847217,
job131457308121, workflow416516267. ARM/macOS15.8.2/Xcode16.4/Swift6.1.2/SDK15.5.

[Original receipt](coverage-preview-attempt-1.json):1,745,312 bytes, SHA256
`f5f2b70b3bd6976d307a772f05d6f918856c619bd379680ad7a6df8f93205bd5`.
[Lossless logs](coverage-preview-attempt-1.log.json) retain19 commands/38
complete EOF/closed streams; all were independently decompressed/hashed.
The688-file vector matches exact native source. Source/index/frozen payloads,
712-entry owned removal and no remaining processes/zero signals verified.
122.671s;200,043,715 max owned bytes,783,908,864 RSS,5 processes. No app/test run.

| Retained original | Bytes | SHA256 |
| --- | --- | --- |
| Framelet-0.1.5-macos-universal.zip | 1,182,752 | 561920944dcaa50ccffb09daebb95ad9d3a5f2761982f65da6dc7ebfea5b3068 |
| ZIP checksum | 101 | 0672e778c4cdf5b8a6e2dc38c359afe846b261c5e3e7d633962de170b536f22d |
| Framelet-preview-manifest.json | 3,228 | 84ad525dc394c9a87c005cc55c773806e357c5a864394e4c156ec0456c9b2de6 |

All3 originals remain inline and were independently decompressed/hashed;
checksum text/manifest/archive digest match. Universal arm64+x86_64,macOS15,
system links/runtime search paths, strict ad-hoc signature/empty entitlements,
exact metadata/icon and extracted bytes/modes verified. Actual source matches
qualified builder/component inputs. Prior FUI03/02/01 evidence is imported at
its original source, not rerun or claimed as new Release acceptance. Manifest
releasePlaybackQualified=false records this non-launching package boundary.

[Exact retirement](coverage-preview-attempt-1-retirement.json) passed7 APIs/
14 complete original streams, disabled workflow and absent unchanged QA ref,
also fresh connected readback. SHA256
`302c5f3bfd6939eb501e2cac734a36f18c6ba3ae1050a10379c3b31ae7b35d9d`.
Local Guard still refused6.7GiB/34GiB; only Python AST/bash syntax/29 qualified
runtime input hashes/plist/diff checks ran locally. Public0.1.3/failed0.1.4 stay
unchanged. This package scope is closed; no routine rebuild or component replay.
Next run the separate full FUI04 on this exact retained archive before any new
usable binary publication. ARM runtime/device/audio/trust boundaries stay open.
