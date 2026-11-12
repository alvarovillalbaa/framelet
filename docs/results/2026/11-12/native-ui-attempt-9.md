# Native edit, reopen and export acceptance — passed

12 November 2026. [Run 43193361098](https://github.com/alvarovillalbaa/framelet/actions/runs/43193361098),
job 131097987270, passed the single complete FUI01 case at source
`d9b12261d92b30e2db40f8ab6b1ae5dac0f2a36b` (tree
`0690ef304d894c63a512874417610c13fc0ff1ed`). No skipped or expected failures.
This is an actual debug/arm64 app run on a disposable macOS 15.8.2 VM, with
empty production-style app entitlements and the normal sandboxed UI runner.

The native journey opened authored media, renamed the recording, trimmed,
duplicated, reordered and removed clips, saved Square/Sand canvas settings,
exported through the real NSSavePanel, terminated, and reopened the saved edit.
All four original screenshots were viewed:
[initial preview](native-ui-attempt-9-01-library-preview.png),
[ordered edits](native-ui-attempt-9-02-edited-clips.png),
[completed export](native-ui-attempt-9-03-native-export.png), and
[reopened library](native-ui-attempt-9-04-reopened-library.png).
The last image clips window edges on the VM's 1024-pixel display; this result
does not establish narrow-window layout or human accessibility acceptance.

An independent host-owned fixture verifier checked saved clip identities,
order and ranges, canvas metadata, unchanged original media hashes, and the
actual MP4. It is 15,109 bytes, duration 1.2 seconds, 1080×1080, with decoded
blue then red center frames. SHA-256:
`10a5753d036647e527b17fdf39e592bd2a4c0a22e4633e09b3e2a8d778e5d679`.
Rendered background pixels are a separate retained-export inspection in the
preview refresh; saved Sand metadata alone is not that proof.

The [complete receipt](native-ui-attempt-9.json),
[lossless original log](native-ui-attempt-9.log.json), and
[retirement receipt](native-ui-attempt-9-retirement.json) retain the result.
Independent data-only review decoded and hash-verified all 36 complete command
streams, every inline attachment, fixture file and output MP4. Source guards
match before/after. Owned app/runner, library and scratch removal passed.
Complete exported attachments, native summary and identities remain; the
passing raw xcresult intermediate was removed only after acceptance/cleanup.

Uploaded artifact 13932336668 is 1,628,388 bytes, server SHA-256
`98ffd33a74e1f39c78da7868626d4acbee970fa38ee3ca02348c5475443368c5`.
Workflow 415811372 was disabled and the exact QA head removed; an independent
ref-prefix read is empty. All eight failed attempts retain their own verdicts,
sources and diagnostics. The old thirty-case and packaging scopes were not
replayed or relabeled as this native profile.

No local app/build/test, real capture, source picker, camera, microphone,
system audio, personal media, account, paid service or model call was used.
Physical capture/permissions/audio timing, trust/downloaded-app launch,
Release runtime on both architectures and full recorder parity remain open.
The public download remains the old 0.1.0 preview until fresh assets publish.
