# Failed raw packet preserved; stale draft URL stopped final readback

12 November 2026. [Run43275726447](https://github.com/alvarovillalbaa/framelet/actions/runs/43275726447),
job131383475963, failed at source `a68918ff307eff8c841637bb9ecc41b0a133db04`.
Native head `7fc1dfd87a4c672d289bae7b31fc6f26874ac7f5` matches tree
`01f1a2e5d7781b850330ba8dafe918bc7eca9261`. No app/build/native rerun.

The current run-artifacts collection admitted the exact original. One archive
download passed: 7,633,128 bytes/SHA-256
`e723317908e0b99fe7f5145f1f0ce53307e623badc11e71e232cde3726a99bbc`.
ZIP metadata has136 entries/10,032,216 expanded bytes, exact failed receipt and
raw `ui.xcresult`. No extraction or execution. Original upload succeeded and
server size/digest matched. Evidence release443326502 is public at
[its failed-evidence tag](https://github.com/alvarovillalbaa/framelet/releases/tag/framelet-release-playback-evidence-20261112-attempt-1),
asset740519926. The failed native verdict remains failed; this is raw evidence.

The controller then incorrectly compared a cached draft asset's `untagged-...`
download URL against the published tag URL. That implementation mistake stopped
before any anonymous request. Keep this run failed. Its temporary-duplicate
cleanup and final source-after guard were consequently not reached; neither is
verified. No claim about ended-VM cleanup follows from later readback.

Independent finally paths successfully disabled workflow416339126 and its own
416360873, deleting only the two unchanged exact QA heads. Fresh independent
connected [metadata/ref readback](compatible-playback-closeout-attempt-1-readback.json)
confirms the published exact asset/tag URL/digest and both refs absent. The
original rejected artifact-metadata URL was not retried and permissions unchanged.

All22 API calls/44 complete original response streams and archive-download stderr/
upload stdout/stderr were independently decoded and byte/hash checked.
[Raw receipt](compatible-playback-closeout-attempt-1.json):49,796 bytes/SHA-256
`b4d7e94fb0cab4774f2d054d5851f1d59268774e030374ecafe0c430b67efcd6`.
[Lossless logs](compatible-playback-closeout-attempt-1.log.json) retain all errors.
Fresh public asset metadata provides preservation proof; anonymous delivery is
still unverified. Complete only that data-only readback using fresh public
metadata, with no repeat upload, new evidence tag or native/control replay.
