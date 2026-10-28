# App-icon source and bundle wiring

28 October 2026. Original icon source and packaging references are published;
no native Framelet build or exported app bundle was produced for this check.

The [editable SVG](../../../../artwork/app-icon.svg) uses a recording screen,
coral record dot and two timeline clips on an ivory tile, with transparent
padding. The [flat PNG reference](../../../../artwork/app-icon.png) is 1024 square,
RGBA and sRGB. It is artwork, not an app or Dock screenshot. No external artwork,
font, raster source, image model, account or network service is used by export.

`CFBundleIconFile` selects `AppIcon.icns`. The packaging helper now creates
`Contents/Resources` and copies that file before its unchanged ad-hoc signing
commands. Removing only those two added shell lines reproduces the old helper
exactly; removing only the icon plist key reproduces the original plist values.
Runtime/core/test/package/CI source and capture/permission behavior are unchanged.

## Format and checks

Apple's [archived high-resolution guide](https://developer.apple.com/library/archive/documentation/GraphicsAnimation/Conceptual/HighResolutionOSX/Optimizing/Optimizing.html)
documents the ten iconset slots: 16, 32, 128, 256 and 512 points at 1x and 2x.
The current [CFBundleIconFile reference](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconfile)
identifies the bundle icon file. The archive is format guidance, not current
distribution or signing acceptance.

On macOS 26.5.2 (25F84), `sips` advertised SVG support but rejected the source
with “Cannot extract image from file.” Native `iconutil` encoding also rejected
the correctly named ten-PNG iconset. The final exporter therefore uses a small
standard-library SVG geometry renderer and ICNS PNG-chunk writer, without
depending on either failed encoding path.

Apple SDK `IconStorage.h` defines the big-endian ICNS resource/element headers.
The PNG/Retina slot mapping is also inspected in the first-party
[Pillow ICNS decoder source, pinned at 75d6d6d](https://github.com/python-pillow/Pillow/blob/75d6d6db2fa61940552fe2df0a54943a5596702b/src/PIL/IcnsImagePlugin.py).
No Pillow dependency was installed or executed. The writer embeds ten original
PNG representations, including separate standard/Retina entries at equal pixel
sizes; it does not redistribute Apple's system icon artwork.

The new exporter and `--check` passed with Python 3.14.7. Its byte comparison
is current-host regeneration evidence; Python/zlib changes may alter bytes.
Independent checks verified ICNS lengths, all ten type/size mappings, every
embedded PNG checksum and 8-bit RGBA format. Apple `iconutil` successfully decoded
the final ICNS into all ten canonical filenames; `sips` confirmed each size and
alpha channel. Native extraction can re-encode PNGs, so no byte-identity claim
is made for the extracted files. The PNG artwork was viewed directly.

`bash -n`, `plutil -lint` and `git diff --check` passed. No original build helper,
Swift compiler/test, app, capture source picker, camera, microphone, permission
prompt, signing, notarization, CI job or browser check ran. Actual bundle
inclusion, OS appearance, native behavior and distribution remain pending.

## Checked bytes

| File | SHA256 |
| --- | --- |
| `artwork/app-icon.svg` | `0aeca7b6a52c16db527051695febe5e5e18f5bce85ef259e12978474ff079c79` |
| `artwork/app-icon.png` | `19bbad57e1b92356e6b5057555d90522a68951239c8aecf9a75753b47eccf23e` |
| `Resources/AppIcon.icns` | `ed7f2e175531299ab2a9a13f9f7aafc75df97d1bce82b0cfc0a383f71f07ba08` |
| `Resources/Info.plist` | `972084508967dcb5fe992aa6b88143e470bdcb0403e80e02ed833f87cb6d6d4d` |
| `script/render_app_icon.sh` | `de9fda2d9e2e0977e88600dab9041cbbb88579ab1de902e8e48c85a6c1460886` |
| `script/render_app_icon.py` | `6f1e5461f072b25267ded787691b6023a891fccfe33d108c21c4284153d66eb8` |
| `script/build_and_run.sh` | `bdba84eea7e875eac860fc54b18b3f952f380ee445dcf20f4143c8f18469556e` |

## Source publication

Published [source commit e25b854](https://github.com/alvarovillalbaa/framelet/commit/e25b85482d15c74b0898001df0841453b02035fb).
Immutable GitHub readback matched the local Git blobs below; `main` was identical
to that source commit at readback. Independent final checks confirmed all ten
ICNS mappings, embedded PNG checksums and reference bytes, unchanged original
plist values/packaging commands after removing the icon additions, six local
documentation links and the nine-file change scope. `git diff --check` passed.
These are publication and source-format checks; native acceptance remains open.

| Published file | Git blob |
| --- | --- |
| SVG | `2984300b48318b1652c86b735c66b8693a71df95` |
| PNG | `93b8376a6e4b73088bf5fabb72d274a2474eb145` |
| ICNS | `fb6d57c5b71406b282cb50b06961a3b8f33919bf` |
| Info.plist | `33173c2cd8b03ab583cf75d254263b5b1e7c5b44` |
| Packaging helper | `485b97fa2afa9449a80e9d609dcd9c8728c0126b` |
| Python exporter | `927b3f981fcbc64ff15581f192a04401e5c48305` |
| Shell exporter | `df3942b80b56d400155734f9245d7e5cb6eff235` |
