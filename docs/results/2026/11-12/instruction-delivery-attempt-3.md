# Instruction delivery: valid instructions, no renderer requests

The [third bounded experiment](https://github.com/alvarovillalbaa/framelet/actions/runs/43289225489)
passed measurement, source/input and cleanup/retirement checks. It does **not**
fix or qualify Recording playback. Both original raw frames were viewed:
[red](instruction-delivery-attempt-3-files/raw-red.png) and
[blue](instruction-delivery-attempt-3-files/raw-blue.png).

| Variant | Valid | Source IDs / pass-through | Frame timing | Requests red/blue | Copied frames |
| --- | --- | --- | --- | --- | --- |
| Raw assembled asset | Yes | None | Default | No compositor | Correct red/blue |
| Current instructions/counting production delegate | Yes | [1] / 0 (invalid) | Default0 | 0 / 0 | None |
| Explicit protocol instructions | Yes | [1] / 0 (invalid) | Default0 | 0 / 0 | None |
| Explicit instructions/source timing | Yes | [1] / 0 (invalid) | Track1 | 0 / 0 | None |

Both contiguous instructions cover0–10.328333s and10.328333–23.079998s,
containsTweening=false/postProcessing=true. All items were ready, both seeks
completed successfully, clocks advanced and no validation/player/item error
was recorded. Raw display times were3.000s and14.886667s for targets3s/15s;
BGRA640x428/IOSurface medians[224,21,12] and[26,46,231]. The explicit variants
retain the exact production drawing/failure body (SHA256
`29830fcf5fe43e6d899823923fca793598dc7807b2abaee096474bf493d4ee46`).
These observations do not support an invalid graph, accidental pass-through,
missing explicit IDs or frame-timing-only repair on this profile. They do not
establish a hardware/GPU cause or behavior on physical Macs.

Source `5fe63a8b71d2cf035448149c77449107e56c3397`, native
`e927293c3c3c8262dcebde05236a6a2d28cecda1`, matching tree
`4fd798c6925ce38a172ebf3cc41bd2f213185db7`; QA
`7ca3e6d3098bef965238a1f7144fdf8814c0c3ea`. Run43289225489,
job131430703050, workflow416450054, Intel/macOS15.7.9/Xcode16.4.

[Original receipt](instruction-delivery-attempt-3.json):522,784 bytes, SHA256
`5e6a8ae0c173cb99d58c74ec8de1f59407a9266b7d4625ccd5f66aa716542f5b`.
[Lossless logs](instruction-delivery-attempt-3.log.json) retain8 commands/16
complete streams and all8 per-row originals. Both621-file vectors match each
other and the exact native source; source/index,3 fixture files and the92
protected product/old-case inputs stayed unchanged. All groups/root absent,
no signals/inspection errors.89.559s; peak79,363,566 apparent/88,821,760
allocated bytes. No Framelet/visible-window/old-case/capture/export/device run.

[Retirement](instruction-delivery-attempt-3-retirement.json) passed8 APIs/
16 complete streams, uploaded scratch removal, exact workflow disabled and
ref absent (also fresh connected readback). SHA256
`5592c67c757c0c62865b37f8c3bf52cbdfab9eb8df0162dd64897001b4dd1bef`.
Artifact13975688732:248,204 bytes, SHA256
`45689b5b1203902316dc5ea156c364b4b250cb6268ee64b5415c9c8120a61ca9`.
Both earlier failures remain immutable. This diagnostic is closed; do not
replay it as a routine check or change shipping code from this negative result.

Next compare factory-generated composition properties and a counted software
CIFilter output control, using actual frame output at the same timestamps.
The earlier visible CIFilter control did not measure this output/callback
boundary. Materialize a separate bounded profile before execution. Keep the
public0.1.3 download unchanged; full repaired-source Release pixels remain open.
