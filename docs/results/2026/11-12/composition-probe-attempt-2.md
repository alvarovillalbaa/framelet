# Historical case guard unavailable in shallow checkout

12 November 2026. [Run 43252413770](https://github.com/alvarovillalbaa/framelet/actions/runs/43252413770),
job `131301505022`, failed before compilation or app/helper/native execution.
Source `50d70b855ed6febfb3e8de80dc6c3b5dc8a10728`, native
`7acaaf45d9c73dd6db32d1d18ead543ce97d002f`, matching tree
`f4a5feb17f5f0e50a9b86f04de2960b652adbfaa`.

The four-commit checkout excluded the older `9c46e84` object used by
`original-case-source`; `git show` exited 128. This was an avoidable controller
ancestry mistake. Preserve the failure. Candidate 3 pins that exact original
15,300-byte case prefix by SHA-256
`941ed334c6987cdc2991070bcfbda568f15da9abedffcf71fd8cf0e3065c6f1d`,
including its terminating newline and the separate-case boundary. The protected
diff uses current measured source `50d70b8`; no extra Git history, changed
native/helper/product/pixel input, weaker assertion or closed-scope replay.

All seven commands/14 complete original EOF streams were independently decoded
and byte/hash checked. Both 477-file source vectors/index match. No library,
released bundle or authored media was created; owned process/root cleanup passed.
Elapsed 2.505 seconds, maximum 32 apparent/4,096 allocated bytes. No new rendering
or native evidence exists for this attempt.

[Raw receipt](composition-probe-attempt-2.json): 255,718 bytes, SHA-256
`9f1fb5225b45b54bee3d282f89587a4e29b751c59cfdab9b6c43706f8e8d6ed1`.
[Lossless log](composition-probe-attempt-2.log.json) retains the exact error.
Artifact `13960215947`: 117,776 bytes, SHA-256
`28aef85559ae2a1d1af502a4732d86d879484946aa4557e0e03ecc4970665f9b`.
[Retirement](composition-probe-attempt-2-retirement.json) verified upload,
removed scratch, disabled workflow `416217398` and deleted unchanged QA head
`d1fa2685f8820e644dc6ec8fb9db761eaf695683`; the exact ref was independently absent.
