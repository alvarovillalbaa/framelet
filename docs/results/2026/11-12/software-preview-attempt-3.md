# Control checks passed; compositor compilation failed on SDK labels

12 November 2026. [Run 43264250052](https://github.com/alvarovillalbaa/framelet/actions/runs/43264250052),
job `131343432908`, failed at source `9909bf8845d10c2965e6dd07549b6c5f38958bb6`.
Native head `b56253deeba46d713d981ab3f0613d5863d9f88e` matches tree
`e1785936989c933f64658efa1bd957d918df3606`. Xcode16.4/macOS15.7.9/x86_64.

Core compilation and all control/source/input/group/root cleanup passed with
zero signals and no permission-inspection error. Actual cache observations
identify eleven in-root `.pcm.lock` aliases to matching unique files in the
same module-cache directories; no external alias was observed. The preserved
sampler snapshots make the previously missing topology explicit.

The compositor/verifier compile exited 1: crop ramp parameters require
`startCropRectangle`/`endCropRectangle`, and opacity ramp parameters require
`startOpacity`/`endOpacity`. The original shorter labels were incorrect.
The SDK also warns that both pixel-buffer dictionaries require Sendable values.
Candidate 4 changes only these labels and dictionary types in the compositor;
Apple's [source-buffer requirement](https://developer.apple.com/documentation/avfoundation/avvideocompositing/sourcepixelbufferattributes)
specifies `[String: any Sendable]`. No pixel case executed and no PNG exists.
Keep this failed verdict; no output/rendering algorithm or test assertion changes.

All eight commands/16 complete original EOF streams, both 512-file source
vectors/index and all three unchanged copied inputs were independently decoded
and byte/hash checked. Exact input bytes are retained inline. All owned groups
were absent and the nonce/inode-owned root was removed. Recorded maxima:
66,703,588 apparent/79,036,416 allocated bytes; elapsed 56.584 seconds.
No app/UI/capture/export/device, old-case, paid or model execution occurred.

[Raw receipt](software-preview-attempt-3.json): 390,373 bytes, SHA-256
`18c1de053f7515ecd88b92286fe4b9272a63d9f96e1fae5057dda3dbe69adbaa`.
[Lossless log](software-preview-attempt-3.log.json) preserves exact compiler
errors, warnings and topology. Artifact `13965990995`: 136,652 bytes, SHA-256
`c1fde29a8bbb404df0264faf857653be73c0d74c6f27c36160b2ace0667fc23f`.
[Retirement](software-preview-attempt-3-retirement.json) passed with eight API
calls/16 original streams verified; exact uploaded scratch removed, workflow
`416292751` observed disabled and unchanged head
`12d7a175b816c3a7e3d3ba2a41d3c0cdcd5bb3ad` deleted. The exact ref was independently
read back absent. Both earlier control failures remain unchanged.
