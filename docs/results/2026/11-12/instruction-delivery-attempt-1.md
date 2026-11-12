# Instruction delivery attempt 1: compile failure

The [bounded job](https://github.com/alvarovillalbaa/framelet/actions/runs/43287495434)
failed before helper launch. The native SDK resolves validation to an async
throwing method; the probe omitted `try await`. No playback measurement or
product fix follows. Correct only that call and retain validation errors as
diagnostic data in the next distinct attempt. Shipping inputs remain exact.

Source `5c8cddf15b4bfead22654d9f36958af4447a91c7`, native
`0de30d160f2d292222074b1c45c12ba9cd6e6c5a`, matching tree
`4d578f18d6ed1007c11370a4b65c5c2b883c64a8`; QA
`d3e37dc09f9aa145ff6fea556c0426890de928cc`. Run43287495434,
job131424642978, workflow416436799, Intel/Xcode16.4.

[Original receipt](instruction-delivery-attempt-1.json): 428,223 bytes, SHA256
`de4bbd17b81f5d0e09639bf0bb66bf4ce443080c9a1d659fdf46c29bedc6af17`.
[Lossless tool log](instruction-delivery-attempt-1.log.json) retains the complete
original command streams. Seven commands/14 complete streams, two equal611-file
vectors/index, three original fixture hashes, all owned groups and root absence
verified. No signal or ownership inspection error. Elapsed35.744s; peak78,885,628
apparent/85,291,008 allocated bytes. Only compilation failed; no app/test launch.

[Retirement](instruction-delivery-attempt-1-retirement.json) passed nine API
requests/18 complete streams: exact current-run artifact/head/digest, uploaded
scratch removal, workflow disabled and exact ref absent. Fresh connected ref
readback also returned empty. Retirement SHA256
`770dd9f9fdf41fb1696a90cc4aec53971aec6598ae4a15fc064c3c60b66aed66`.
Artifact13976660613 is152,821 bytes, SHA256
`191ac346dc8987426d97efa669286dd4621e2d6e0c157930d909b309bedf620b`.

No closed native/component case ran. Local syntax/static checks cannot establish
the corrected helper's native build or playback; preserve this failed verdict.
