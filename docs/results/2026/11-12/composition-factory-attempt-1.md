# Factory output: system and counted CIFilter paths render

The [bounded comparison](https://github.com/alvarovillalbaa/framelet/actions/runs/43290849001)
passed measurement/source/input/cleanup/retirement. All6 original PNGs were
viewed in [the retained directory](composition-factory-attempt-1-files/).
Shipping code stayed exact; no playback fix is established yet.

| Variant | Output red/blue | Requests | Properties |
| --- | --- | --- | --- |
| Raw asset | Correct / correct | No compositor | 640x428 |
| Generated properties factory | Correct / correct | System compositor | 640x428,23426/90000s,source timing1 |
| Factory copy with product settings/delegate | None / none | 0 / 0 | 1920x1080,1/30s,source timing0 |
| Software CIFilter | Correct / correct | 5 / 10 cumulative | 640x428,23426/90000s,source timing1 |

All items/instructions validate, seeks finish and item/player errors stay empty.
Factory display times3.383756s/15s; filter3s/15s. Raw/factory RGB medians
[224,21,12]/[26,46,231], filter[221,40,5]/[39,61,234]. The filter rejected one
stale3.828333s frame during the blue seek and accepted the actual15s frame.
Source track1 is640x428/identity transform, nominal3.841775fps; asset23.08s.
Generated instructions cover the asset exactly. Product final end23.079998333s
is about1.667 microseconds shorter. Color properties are nil in all paths.

The comparison changes several product settings together; it does not isolate
render size, frame duration, instructions, custom class or final coverage as
the cause. A separate one-property comparison is the next useful scope, with
validation over the actual asset duration as well as the project duration.
Keep all shipping inputs exact until that result; no GPU/hardware inference.
The CIFilter control processes only the first enabled track and supplies no
multi-track camera replacement. Primary API contracts are linked in
[the proposal](../../../proposals/composition-factory-checks.md).

Source `97a466b114749ae9908122a93856a0128bd0e383`, native
`c3b3b2135080061a0991488d7fd6202171a77408`, matching tree
`3f08b414f58dbf724cb0c01fd90bd90e706a0761`; QA
`652d87bd95a038623015441a6ff5f785206a5306`. Run43290849001,
job131436372701, workflow416463598, Intel/Xcode16.4.

[Original receipt](composition-factory-attempt-1.json):628,465 bytes, SHA256
`004cbed017d260ef04185905a6bc0677f9e8f6d7aa648c260b9623f07139055a`.
[Lossless logs](composition-factory-attempt-1.log.json):8 commands/16 complete
streams,8 rows,6 original frames, two632-file vectors equal and exact native
source,95 protected inputs, fixture/index, groups/root absence verified. No
signals/inspection errors.81.667s;79,440,241 apparent/89,907,200 allocated bytes.

[Retirement](composition-factory-attempt-1-retirement.json) passed8 APIs/
16 complete streams, exact artifact/head/digest, uploaded scratch removal,
workflow disabled/ref absent (also fresh connected readback). SHA256
`9b83e761749a9bf1b3b5baf8f3a3e684d99e659cd3dca414ef95b1f2e957989d`.
Artifact13976873734:396,629 bytes, SHA256
`fbbfe79aaf0093d9fd75d9b054ca92716c4e9e8d35a1203cb049fc76fb1dbe53`.
No Framelet/visible-window/old-case/capture/export/device action. This scope is
closed; preserve all earlier failures and the unchanged public0.1.3 download.
