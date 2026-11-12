# Exact composition controls retired without a native rerun

12 November 2026. [Run 43255123842](https://github.com/alvarovillalbaa/framelet/actions/runs/43255123842),
job `131311156334`, passed the data-only closeout at source
`e41027a9a65ede0f8671a077c4dd8b9494e9fa52`. Native head
`313567896658e3d1dc648456052a8a6aeef0c31d` matches tree
`d53e41adf3a3e2a34f29629fb23b5ab34187a47f`.

Fifteen API calls/30 complete original stdout/stderr streams were independently
decoded and byte/hash checked. The helper verified the exact passed diagnostic
receipt, native/upload success and retirement-only failure, and artifact
`13959324008` with its 825,196 bytes and exact server digest. Workflow
`416220974` was observed `disabled_manually`; unchanged native QA head
`eaf30d07051525b2bbeb38ffbc7d1f3223893fab` was deleted and read back absent.
The helper then disabled workflow `416235752`, observed that state, deleted
only its own unchanged head `4aa83aef434c0c48d6086b42b2d3500488ad65bb`, and
observed its ref absent. Both exact refs were independently read back absent
through the connected tool. Source stayed unchanged. No app/build/native/model
execution or artifact rewrite occurred.

[Raw receipt](composition-control-closeout.json): 32,095 bytes, SHA-256
`adbb3619e97ff7e612cbb1452ecc1e98bef5803b38a855998f6109c8417ea94c`.
The [lossless log](composition-control-closeout.log.json) preserves the original
receipt and successful job. This closes remote controls only. Ended-VM evidence
scratch was not independently reopened; the original native-owned-root cleanup
is separately verified. Keep the original failed retirement and both diagnostic
failures unchanged. The passed FUI04D diagnostic is closed; the full FUI04
recording-preview pixel requirement remains failed and requires a product repair.
