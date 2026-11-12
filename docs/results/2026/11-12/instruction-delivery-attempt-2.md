# Instruction delivery attempt 2: failed raw control

The [second job](https://github.com/alvarovillalbaa/framelet/actions/runs/43288181207)
compiled and ran the background helper, but failed its raw-color control before
final metadata emission. Both retained original PNGs show red, including
[the requested blue phase](instruction-delivery-attempt-2-files/raw-blue.png).
No valid instruction/callback result follows; absent composed PNGs alone are
insufficient. The first image is [here](instruction-delivery-attempt-2-files/raw-red.png).
Both original files were viewed without modification.

The sampler could accept a buffer before seek completion and did not require
its display timestamp to match the target. A stale frame is a plausible cause,
not established by missing metadata. Attempt3 requires successful completed
seek and an actual display timestamp within the target interval; it records
rejected timestamps and every row to retained stderr before final assertions.
Keep the same raw-color assertion, source, render algorithm and resource bounds.

Source `16a5818d9d76f72d83fa63eee90a87e00af2075e`, native
`203e26cf5f35d310b6632e087cd86ba75e7d78d7`, matching tree
`553e0ef06fa0d8168bbd4fd3ea982f53be886e73`; QA
`fa76e6040f94a8cc7f655e26509ccf4a7dfe5656`. Run43288181207,
job131427051252, workflow416441808, macOS15.7.9/Intel/Xcode16.4.

[Original receipt](instruction-delivery-attempt-2.json):527,387 bytes, SHA256
`f6481b44fb10250ff68c3b8712f13766be08c7bb38c2b6daaa01aacc35f6f961`.
[Lossless logs](instruction-delivery-attempt-2.log.json) retain all8 commands/
16 complete streams. Two equal615-file source vectors/index,3 fixture inputs,
all groups/root absence verified; no signals or ownership errors.109.076s;
peak79,316,007 apparent/90,255,360 allocated bytes. Shipping inputs unchanged.

[Retirement](instruction-delivery-attempt-2-retirement.json) passed9 APIs/
18 complete streams, exact artifact/head/digest, scratch removal, disabled
workflow and absent exact ref (also fresh connected readback). SHA256
`3e537ab3e3d2ffc238e9a0f4660a820299ed2d0b748144e53494bb430087533b`.
Artifact13975702323:224,905 bytes, SHA256
`8b19afe9f887c55d2eaa38c871d6fd3a8c42629b8801f8e5525b07b2d79a7783`.
No product/native/old-case run, capture/export/device action or release occurred.
