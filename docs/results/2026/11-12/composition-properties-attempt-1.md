# Property comparison attempt1: helper compile failure

The [bounded job](https://github.com/alvarovillalbaa/framelet/actions/runs/43292480894)
failed before helper launch: a local composition named `instructions` shadows
the static reporting function. Qualifying the report call as `Self.instructions`
corrects this binding without changing any variant or assertion. No playback/
property/coverage result follows from this attempt. Preserve this failed verdict.

Source `00dd9256c4fe50bd9113a1fade12ffe8f7bed09e`, native
`d03358e551eebf32a8d339bb10fd5596359b080d`, matching tree
`46dd02861ee708a4d44a85fca099334090287460`; QA
`108756a9015a98679949bf785179fbca497d3523`. Run43292480894,
job131442041900, workflow416477506, Intel/Xcode16.4.

[Original receipt](composition-properties-attempt-1.json):458,292 bytes, SHA256
`478b7057bace56d6680db7f0a593eb59e6421dce4f73fc664b9670d0fc4c5321`.
[Lossless logs](composition-properties-attempt-1.log.json) retain7 commands/
14 complete streams, two equal647-file vectors/index, exact fixture inputs,
all groups/root absence. No signals/inspection errors.45.551s;78,611,392
apparent/88,014,848 allocated bytes. Shipping and98 protected inputs unchanged.

[Retirement](composition-properties-attempt-1-retirement.json) passed8 APIs/
16 complete streams, exact artifact/head/digest, uploaded scratch removal,
workflow disabled/ref absent (also fresh connected readback). SHA256
`72c5cfa2eb89861f523dfda46cf09c28aaff8aa0b8320400df5eccdf86d1e0f4`.
Artifact13977497467:179,899 bytes, SHA256
`6cdd17b24f28b534b3ea33afe69bebb6886145be103c5287587afc6ea95bb213`.
No app/visible-window/old-case/capture/export/device action. Attempt2 retains
all16 measurements, both controls and every resource/source/cleanup boundary.
