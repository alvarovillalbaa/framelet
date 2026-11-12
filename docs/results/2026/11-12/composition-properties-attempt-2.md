# Root cause: instructions stop one project tick before the asset

The [corrected property experiment](https://github.com/alvarovillalbaa/framelet/actions/runs/43293244242)
isolates the failure. Original instructions end at23.079998333333332s, while
the inserted native asset lasts23.08s. Validation over the project range passes;
validation over the actual asset and all times fails. Extending only the last
instruction end to23.08s restores both real colors at1920x1080 through the
unchanged product renderer (8/16 cumulative callbacks).

| Independent variant | Full asset/all-time valid | Frames red/blue |
| --- | --- | --- |
| Raw and generated controls | Yes | Correct / correct |
| Only custom product renderer | Yes | Correct / correct;7/10 requests |
| Only frame duration1/30 | Yes | Correct / correct |
| Only render size1920x1080 | Yes | Both available; unscaled source in larger matte |
| Only original instructions | No | Neither |
| Only final coverage corrected, factory settings | Yes | Correct / correct |
| Only final coverage corrected, product settings | Yes | Correct / correct;8/16 requests |

This establishes the coverage defect for the authored recording on this profile;
size/rate/custom renderer do not individually reproduce missing output. The
gap is1/600000s, approximately1.667 microseconds. Source insertion uses native
media timescales while the edit clock uses600000. The builder correction must
cover actual asset time, keeping project edit/audio/presentation settings intact.
Primary [validation semantics](https://developer.apple.com/documentation/avfoundation/avvideocomposition/isvalid(for:timerange:validationdelegate:))
explain why a project-limited check missed it. No GPU absence inference follows.

[14 original PNGs](composition-properties-attempt-2-files/) are retained. Six
critical originals were viewed: custom, corrected factory and corrected product,
each red/blue. Corrected product images show the full upright header/matte at
1920x1080, display3.1s/15s and RGB[222,40,6]/[40,61,235]. All16 row originals
precede final assertions in retained stderr; item/player errors stay empty.

Source `0c2bf6646e4075df60f9d2db49ae1d631940bea8`, native
`1eed88301fa9db48b7fdfeddf979c0de8ea7552a`, matching tree
`d4c845b61962d2deede05dd0c24594b11c064527`; QA
`3ea267536369cf34a4fc9609fb3eeae7e6ad5b8e`. Run43293244242,
job131444683152, workflow416484411, Intel/Xcode16.4.

[Original receipt](composition-properties-attempt-2.json):977,953 bytes, SHA256
`e2753728edf72a76cafb999549949c949e21005dd8072c152c328f65341193dc`.
[Lossless logs](composition-properties-attempt-2.log.json):8 commands/16 complete
streams,16 rows,14 PNGs, two651-file vectors equal and exact native source,
98 protected inputs/index/fixture/groups/root verified. No signals/inspection
errors.53.563s;80,038,520 apparent/86,532,096 allocated bytes.

[Retirement](composition-properties-attempt-2-retirement.json) passed8 APIs/
16 complete streams, exact artifact/head/digest, uploaded scratch removal,
workflow disabled/ref absent (also fresh connected readback). SHA256
`644ce7ea1e12bc2799f33a212c74299bd29d0d1084093ad81c4fc173b0b397fa`.
Artifact13979010998:917,988 bytes, SHA256
`878b447d7b9d2d0996127718ae87b40aecb9edd342ea2abe5a402b8d2bfe8543`.
No Framelet/visible-window/old-case/capture/export/device action. The diagnostic
is closed; preserve its compile failure and every earlier failed verdict.

Next verify the exact builder correction through the actual product class with
original/fractional-trim/reordered projects. No test-time coverage mutation in
that regression. Full new-source Release/native pixels remain mandatory before
another usable binary release; the public0.1.3 archive stays unchanged.
