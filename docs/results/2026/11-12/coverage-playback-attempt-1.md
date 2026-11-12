# Full0.1.5 Release playback passed

The [complete FUI04 run](https://github.com/alvarovillalbaa/framelet/actions/runs/43298428068)
passed the unchanged ten-phase native journey **and all nine required rendered
color checks** on the exact retained0.1.5/build6 Release app. All ten original
PNGs in [the retained directory](coverage-playback-attempt-1-files/) were viewed.
Recording now shows red/blue through continuous boundary, seeks, end/replay and
reopen; Selected Clip resets duration and renders the chosen take correctly.
The initial paused frame is also red, although the verifier does not require it.

Actual Release PIDs2959/7564 match every native phase and the bound exact app
executable path. The extracted bundle files/modes/hashes match the package
manifest before and after, without resigning or modification. Three source
media/manifest inputs plus the acceptance-owner file remain unchanged; actual
no-selected-source/disabled-Start/no-capture safe shutdown acknowledged.
All owned processes/library/root are absent. Debug dependency is only a build
input; the native target is rebound to the unchanged Release bundle.

Source `6c4cdfe4e993af852ed43a59c150e4f8c425e7cf`, native
`d3dd3de1d9f58f9981762c5d8b2afc2ecbd855a7`, matching tree
`3dd34a75b181840384da2709789bc55a66d01812`; QA
`1d93059c444ec43148f01eb3c10a987b86b34c90`. Run43298428068,
job131462819416, workflow416525496; Intel/macOS15.7.9/Xcode16.4.
Package source0b2a03c0, unchanged ZIP SHA256
`561920944dcaa50ccffb09daebb95ad9d3a5f2761982f65da6dc7ebfea5b3068`.

[Original receipt](coverage-playback-attempt-1.json):3,877,432 bytes, SHA256
`24d39964807d36f7f6ac458af59ea10b35f0c97568ec637c77c1670b876b8f67`.
[Lossless logs](coverage-playback-attempt-1.log.json) retain15 commands/30
complete EOF streams. Independently verified23 original attachments,4 authored
inputs, all10 PNG hashes against verifier inputs, two equal696-file source
vectors against exact native commit, source/index and bundle/input preservation.
No signals or ownership inspection errors. Native240.079s; overall370.898s.
Peak27,190,151,981 apparent bytes with the explicitly scoped sparse-cache leaves,
417,378,304 allocated. Full-source and pixel/native case bodies stayed exact.

[Retirement](coverage-playback-attempt-1-retirement.json) passed9 APIs/18
complete streams: exact artifact/run/head/digest, uploaded scratch removal,
disabled workflow and absent unchanged ref, also fresh connected readback.
SHA256 `6a9116b9c6c71280abe87ac68d6b1dd166fc0a0bcd3274b1cb4ff5d4c9e8bbf8`.
Artifact13979708897:5,045,473 bytes, SHA256
`33b65ef6984038dc677512691138405c60d96edc55ff83de9723f6b1c19eb9c7`.
Both original/bound xctestrun plists remain in that two-day artifact; their hashes
and exact declared edits remain in the receipt. The passing raw xcresult
intermediate was removed only after the full verdict, as approved.

The [small qualification record](coverage-playback-qualification.json) captures
this later Release result without modifying the immutable packaging-time manifest.
Its1,360 bytes/SHA256
`cb92b382af8c48bff74d8f45a8a96c1855e5acfaa535198257eff625414cb990`
are ready for the separate exact-asset publication helper. This full native scope
is closed; do not repeat it routinely or rebuild unchanged assets. Preserve all
prior failures and old releases. ARM runtime, CPU cost, physical devices/displays,
camera/audio/encoded-anchor timing, migration, human accessibility and trusted
downloaded-app launch are outside this successful Intel VM playback scope.
