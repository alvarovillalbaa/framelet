# Six compatible-preview cases passed with original output pixels

12 November 2026. [Run 43267327316](https://github.com/alvarovillalbaa/framelet/actions/runs/43267327316),
job `131354299340`, passed at source `a83e00ab139b31788f40cc8f2d062fc3079c3d82`.
Native head `5efcfd3952d797dc84b4b3e5f2186f6e16dbaf30` matches tree
`2fd9d09c5608bb72505a88f9f151b212963d8235`. Xcode16.4/macOS15.7.9/x86_64.

Both compiler commands passed without stderr. All six unchanged cases passed:
ordered red/upright header/Midnight matte, second blue take, reversed Square/
Sand, camera PiP crop/position, side-by-side gap/overlap and Portrait mirroring.
The actual custom compositor was instantiated for all eight decoded frames;
each has the expected dimensions and exact requested time. Red sampled
`[222,40,6]`, blue `[40,61,235]`, upright header `[247,247,247]`, gap
`[26,35,54]`. Mirrored mean error is 0.978; changed-pixel fraction is 0.0211.

All [eight original PNGs](software-preview-attempt-4-files/01-recording-red.png)
were independently decoded, byte/hash checked and visually inspected. They
show the actual captured header, correct canvas/matte, confined camera crop,
empty camera gap, blue overlap and reversed authored camera text. No synthetic
replacement or assertion relaxation. All three failed originals remain intact.

All nine commands/18 complete original EOF streams, both identical 517-file
source vectors/index and three unchanged copied inputs were independently
decoded and byte/hash checked against the reviewed native Git tree. The exact
three input files are retained inline. All owned groups were absent and the
nonce/inode-owned root was removed. Maxima: 68,024,759 apparent/77,434,880
allocated bytes; elapsed 58.940 seconds. No signals or inspection errors.

[Raw receipt](software-preview-attempt-4.json): 1,049,795 bytes, SHA-256
`cf55dd928530d3ad95ecdd89cf24cf5a299a847d9aae05ffd9632fc6e1cc3414`.
[Lossless logs](software-preview-attempt-4.log.json) retain all original streams.
[Artifact](software-preview-attempt-4-artifact.json) `13965943655`: 1,116,384 bytes,
SHA-256 `6d55c12de03acd391e3df38d0bf72618bef5c85654cdb9e7b1bcdad1a757715e`.
[Retirement](software-preview-attempt-4-retirement.json) passed; all eight API
calls/16 original streams verified. Workflow `416310865` was observed disabled,
uploaded scratch removed and unchanged head
`554668d4507641eaddea6d9feb351a7409dc8818` deleted. Independent exact-ref
readback returned no refs. Retirement receipt SHA-256:
`efc9c5209a010068fa1c4d292d671ac6f6fca09004c2e413fc4a66bfbc47fb37`.

This closes only the six-case software-compositor profile. No Framelet app,
UI, capture, export, device, old-case, paid or model execution occurred.
UIPlaybackModel integration still needs a whole-app build. Public 0.1.3 assets
remain unchanged and their full FUI04 result remains failed at its original
source. Next: new 0.1.4/build 5 universal package, then the complete unchanged
FUI04 native/nine-color/process/input journey against that exact Release app
before any new public binary. CPU cost and physical-device behavior remain open.
