# Exact-source playback regression passed

The [fixed-source job](https://github.com/alvarovillalbaa/framelet/actions/runs/43295069794)
passed all3 projects/6 actual AVPlayer frames using the product builder and
`SoftwareRecordingCompositor` class directly. No test-time instruction patch,
forwarding class or substitute renderer was used. All6 original PNGs in
[the retained directory](exact-coverage-attempt-1-files/) were viewed.

| Project | Asset / final instruction end | Full/all-time valid | Actual3s /15s |
| --- | --- | --- | --- |
| Original | 23.08s /23.08s | Yes / yes | Red / blue |
| Fractional trims | 22.94543s /22.94543s | Yes / yes | Red / blue |
| Reordered | 23.08s /23.08s | Yes / yes | Blue / red |

All outputs1920x1080, actual display times3s/15s, upright headerRGB[247,247,247],
matte[26,35,54]. Red[222,40,6], blue[40,61,235]. Both seeks complete for every
case; item/player ready/error-free, actual product compositor verified. Original/
reordered project clock23.079998333s remains intact while instructions now cover
the native asset. Trims/reorder exist only in memory; original inputs unchanged.

The eight-line builder correction is supported by the [causal matrix](composition-properties-attempt-2.md)
and this direct regression. This closes the new background scope, not app-level
Release qualification. Preserve failed0.1.4/full-native verdicts and every earlier
diagnostic failure. Public0.1.3 is unchanged; next materialize a fresh0.1.5
universal package and same-source full Release/native pixel scope before publishing
any usable new binary. No need to repeat closed component/native/capture cases.

Source `3e822abc43c32d3ce4dd3addf4a0baff5aa4861d`, native
`d976941b807c4632dd164dd16747d48b71a845c4`, matching tree
`a4a4e2d1a61596ced02edebcd6fdccfa01ea206c`; QA
`f9f6acc8496003f8ab396c1ae43c21e90fff7f31`. Run43295069794,
job131451067945, workflow416501329, Intel/Xcode16.4.

[Original receipt](exact-coverage-attempt-1.json):1,030,604 bytes, SHA256
`c99ff8177e18c79b59e83109dd10bf38cb08796116270926d4a7f89027f7deb3`.
[Lossless logs](exact-coverage-attempt-1.log.json):8 commands/16 complete
streams,3 cases/6 rows/6 PNGs, two674-file vectors equal and exact native source,
100 other protected inputs/index/fixture/groups/root verified. No signals/
inspection errors.36.005s;79,848,724 apparent/85,344,256 allocated bytes.

[Retirement](exact-coverage-attempt-1-retirement.json) passed8 APIs/16 complete
streams, exact artifact/head/digest, uploaded scratch removal, workflow disabled/
ref absent (also fresh connected readback). SHA256
`945d0b978ad941552935d76fd004db99f74bba79433be4d2e750b1b6a2dd63ab`.
Artifact13979715154:1,030,827 bytes, SHA256
`2e5e9c2427f881df32056772626731bd24b6a2dddd47d0b735f59aae194b8ad9`.
No Framelet/visible-window/old-case/capture/export/device action. Local syntax,
Python AST/static input/diff checks passed; no local build/test/app after Guard
refusal. ARM runtime, physical devices/camera/audio, migration, human accessibility
and trusted downloaded-app acceptance remain open.
