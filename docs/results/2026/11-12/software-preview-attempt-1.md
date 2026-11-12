# Process-group observer failed before pixel checks

12 November 2026. [Run 43259297798](https://github.com/alvarovillalbaa/framelet/actions/runs/43259297798),
job `131325964794`, failed the six-case compatible-preview profile at source
`c3c13849e9fade70c0cb51a133ea88f045156882`. Native head
`e0809922fb2dc1395796a05eefc92764e39a1884` matches tree
`b19a36adf51b6415ddf271b58c64208da3dab287`.

The controller entered FrameletCore compilation, then `os.killpg(pid, 0)`
raised `PermissionError: Operation not permitted` during its final group
inspection. That exception escaped the command recorder; the compile's actual
exit/streams were lost. Cleanup's source-guard command repeated the same
observer failure and also lacks a final command record. Do not reconstruct or
reclassify those missing outcomes. The compositor/verifier were not compiled
or run, no image exists, and source-after/index, input-copy-after, group and
owned-root cleanup are unverified. There is no product or pixel verdict.

Five prefix commands/ten complete original EOF streams were independently
decoded and byte/hash checked. The initial 502-file source vector and three
hash-pinned fixture-copy inputs were admitted. Only one source vector exists.
Last recorded maxima were 101,960 apparent/126,976 allocated bytes; these are
not a verified peak after the interrupted compile. Elapsed 11.101 seconds.
No app, capture, export, device, paid service or old-case execution occurred.

The changed controller uses bounded read-only PID/PGID/UID/command metadata,
never retries signal-zero or requests more process rights. It signals only a
still-live original compiler/read child whose entire observed group has the
current UID; denied/unknown ownership remains a failed retained outcome.
Always record observed streams even if inspection fails. Perform source/index,
fixture-copy and final group checks independently during the existing cleanup
budget. Shipping compositor/model and all six pixel cases remain unchanged.

[Raw receipt](software-preview-attempt-1.json): 142,773 bytes, SHA-256
`7b752fd2815e8b247200e0814900a8b3d824fe63bf76ba5a498266a4808c4d43`.
[Lossless log](software-preview-attempt-1.log.json) preserves both exact observer
errors. Artifact `13962148683`: 56,299 bytes, SHA-256
`d2894c9e843dba5cf0a8feb532a85583d45de00eea7387bf3d570d0bf7d9bad3`.
[Retirement](software-preview-attempt-1-retirement.json) passed: nine API calls/
18 original streams verified, exact artifact uploaded, evidence scratch removed,
workflow `416262178` observed disabled and unchanged QA head
`3c167c695a20a38f2c2dff2584ee1a0fc37d14d4` deleted. Its exact ref was independently
read back absent. Remote retirement does not close the missing native-root proof.
