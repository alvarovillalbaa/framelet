# Framelet 0.1.1 preview publication — passed

12 November 2026. [Run 43196968069](https://github.com/alvarovillalbaa/framelet/actions/runs/43196968069),
job 131110285279, published the three unchanged
[qualified assets](preview-refresh-attempt-1.md). The data-only Linux job ran
no app, build or test. Public prerelease
[442765166 / v0.1.1-preview.1](https://github.com/alvarovillalbaa/framelet/releases/tag/v0.1.1-preview.1)
was published at 10:03:52 UTC. Its tag points exactly to checked package source
`618cabda9b08b04604dbb7992e8c4f73ff9606a8`.

| Public asset | Asset ID | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| `Framelet-0.1.1-macos-universal.zip` | 738972227 | 1,159,292 | `0a02be066db9936c35decab2b32e4892cbf1c75b97ed3d2188c0abc420a78fce` |
| `Framelet-0.1.1-macos-universal.zip.sha256` | 738972230 | 101 | `f7631379c8b09a575a5016967254336237cc85c18a6e9716cbb4be378edd57dc` |
| `Framelet-preview-manifest.json` | 738972234 | 2,617 | `a05a21480e2df7852911a09b16f6f4fc378f1d4901de2c4022eff164e6158bd5` |

All three fresh anonymous downloads returned HTTP 200 with these exact sizes
and hashes. The requests used no token, cookie or Authorization header. Both
older release/tag/asset sets were checked unchanged before and after:
0.1.0's ZIP/checksum/manifest and the separate complete failed-attempt-5 archive.
The [complete publication receipt](preview-refresh-publication.json) and
[lossless job log](preview-refresh-publication.log.json) retain the evidence.

[Independent connected-tool readback](preview-refresh-public-readback.json)
confirmed the public tag, prerelease status, asset IDs/sizes/server digests and
absence of this task's UI/refresh/publication refs. Three older already-retired
0.1.0 QA refs remain preserved; no global QA-ref absence is claimed. The
publication helper verified its owned scratch removal, disabled workflow
415836143 and removed only unchanged QA head
`310094ab00e5b32758197743ed569b830afcfc95`.

The download is an ad-hoc developer preview, without Developer ID/notarization.
Actual capture/permissions, camera/audio synchronization, physical devices,
human accessibility, Release runtime and downloaded-app/Gatekeeper launch
remain open. Native screenshots also reveal an oversized reopened window on
the 1024-pixel VM; that sizing defect is recorded in the product/distribution
docs. No old accepted checks were replayed, no paid service/account was added,
and Storage Guard's refusal of local execution stayed intact.
