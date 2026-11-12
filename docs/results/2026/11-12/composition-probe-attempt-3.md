# Read-only composition diagnostic passed; retirement readback failed

12 November 2026. [Run 43253033480](https://github.com/alvarovillalbaa/framelet/actions/runs/43253033480),
job `131303740674`, passed the FUI04D diagnostic at source
`c4a740687047d0f67c8d24520db52d5a7164fd69`. Native head
`94d8d22598abf0c7af0cb9c5529aec8de8338169` matches tree
`5096ff4a647ef11b2ecf3f02a562aeefeaaf5131`. Xcode 16.4,
macOS 15.7.9/x86_64; one diagnostic native pass, no failure/skip/expected failure.
The overall workflow failed later in retirement, not in this native scope.

Canonical host executable observations, original AX and JSON all bind PID
`3986` to the exact owned CompositionProbe executable. Its 725,296 bytes retain
SHA-256 `2f4d594359f88ec0747793401df5ce5c76b614fbb15954f7300ce3871809dd77`
before/after. No denied path or observed Framelet product launch. Original PNG
inspection shows black for the exact builder, explicit unity/half render scale
and disabled postprocessing, while software Core Image and raw asset show red.
All six players/items are ready, report no errors and advance beyond 3 seconds.
The original builder's actual renderScale is already 1, frame duration 1/30,
two instructions, source-timing ID 0 and 1920x1080 presentation. Scale 0.5
reports 960x540 and still black. The software control is source-sized 640x428
and does not reproduce presentation geometry; do not substitute it for a
qualified recording renderer. The comparison does not establish GPU absence,
physical-Mac behavior, camera/audio or a universal product fix.

The complete FUI04 product requirement remains failed. Its observed native
interaction journey and selected-clip pixels are retained; assembled Recording
pixels require a separately implemented and fully checked correction. No further
unchanged comparison replay is needed. Keep every earlier failed original.

All seventeen commands/34 complete original EOF streams, four inline originals
and four authored inputs were independently decoded and byte/hash checked.
Both 482-file source vectors/index, released input bundle, helper executable
and actual authored library remain unchanged. Acknowledged ordinary helper
shutdown and owned app/runner, library and root cleanup passed. Raw native result
is retained. Peak allocated 462,688,256 bytes; apparent 27,234,414,819 under the
same exact sparse-cache limits; elapsed 217.949 seconds.

[Raw receipt](composition-probe-attempt-3.json): 735,731 bytes, SHA-256
`278c5a1eb3d3b936f3103e2d16189818b310ca33ccc72e2211d34994a2ec5595`.
[Lossless log](composition-probe-attempt-3.log.json) and original PNG/AX/JSON
retain all evidence. Artifact `13959324008`: 825,196 bytes, SHA-256
`99fc4ed4b355621f6aa69dbc18e7c6e04186a27646248666ae69b721d3cb13ac`.

The retirement helper reached line 50: its immediate state read after an
accepted disable request was not `disabled_manually`, and it stopped before
branch deletion. There is no final retirement marker. Connected readback still
found exact QA head `eaf30d07051525b2bbeb38ffbc7d1f3223893fab`; the connector
rejects the workflow-state endpoint. Do not claim disabled/deleted controls from
an accepted request. Use the separate bounded data-only closeout to verify
current state and retire the exact head, preserving this failed retirement.
