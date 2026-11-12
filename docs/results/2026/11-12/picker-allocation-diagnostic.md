# Unallocated picker diagnostic and retirement — passed

12 November 2026. [Data-only run 43213446916](https://github.com/alvarovillalbaa/framelet/actions/runs/43213446916),
job 131166601893, read the original failed job/check metadata and retired only
the exact unallocated picker control and itself. Source
`7a0cd7f8e1dd338f3cf43f017a6fb1259d293c04`; QA
`9fa48318c097b2ebb48e15e74e0c18d5f1a498aa`.

The [original receipt](picker-allocation-diagnostic.json) and
[lossless job log](picker-allocation-diagnostic.log.json) preserve eighteen
bounded requests. Receipt SHA-256:
`a5b1a3ee1300efe808452bfcc811723fcdff7041d26a72278d25797a6ad92fa9`.
The provider reports failure to acquire a hosted runner and explicitly cites
macOS ARM capacity constraints. This is not an app/test, auth or billing result.
The [original attempt](picker-readiness-attempt-1-allocation.md) stays failed.

Workflow 415923331 was disabled and only unchanged original QA
`28ac1d1bd33ec7f1e23038cd17c1d276523ff4ce` removed. Diagnostic workflow
415941158 was disabled and its unchanged QA removed. Both refs were independently
read back absent through the connected GitHub tools. No executor/app/library
resources were ever created by the cancelled native job. No app, build, native
test, screenshot, picker/consent, capture, device, local environment or model
ran in this diagnostic. Its successful cleanup supplies no missing native proof.

The prepared [candidate 2 Intel profile](../../../proposals/picker-readiness-checks.md)
can now execute once under its separate source/architecture boundary, with
the original FUI03A body and source-review control corrections. Closed FUI01,
FUI02, packaging and retained-pixel scopes remain untouched.
