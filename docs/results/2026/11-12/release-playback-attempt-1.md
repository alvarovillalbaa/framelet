# Release playback stopped before native execution

12 November 2026. [Run 43237241362](https://github.com/alvarovillalbaa/framelet/actions/runs/43237241362),
job `131247743581`, failed at source `63b3282a8e8752e34832fc261f756339804fcd10`.
Native head `dab035fb772ca49ca8a2855456c7559284605b0d` has the same tree
`bfc853c673e00cb7823a7b7ac6356d30416f09a5`. The failure occurred during
`build-for-testing`, before xctestrun binding, app launch or any native case.
It is a controller/storage failure, not a playback result.

The owned-storage sampler asserted that apparent bytes exceeded its 4 GiB cap.
The last successful stored sample was 117,122,503 bytes; the failing size,
largest paths and allocated blocks were not retained, so the cause cannot be
attributed to a particular cache, sparse file or hard link from this evidence.
The uncaught sampler exception also lost that command's original streams and
made the cleanup source guard repeat the same storage assertion. Those gaps
remain explicit; do not reconstruct or claim missing command/source proof.

Nine preceding commands/18 complete streams were decoded and byte/hash checked.
The exact released archive extraction, payload admission, strict signature,
empty entitlements and new pixel-verifier compilation passed. The Debug harness
build did not return a verdict. Four authored input files (new nonce marker,
unchanged manifest and both real originals) were retained and hash checked in
[the original receipt](release-playback-attempt-1.json), with
[lossless job log](release-playback-attempt-1.log.json). Receipt SHA-256:
`57be1252554e280e6ac25a98be6b2ef95adc1057144ce5bafd6b375a0a415b5c`.

No runtime observation, app launch, capture/export or native result exists.
Owned library/root/process cleanup is unverified; VM expiry is not cleanup
proof. The original failed verdict stays unchanged. The changed control must
retain sampler magnitude/topology and complete observed command bytes on
exceptions, and allow read-only cleanup guards to report a storage failure
without suppressing source inspection or safe owned cleanup. Keep the same
4 GiB cap until actual diagnostic evidence supports a different correction.

Artifact `13954120465` is 132,348 bytes, SHA-256
`c33995919a6c92dd2976d3ae38cce7d604e6fd81e93217262df66d296ace47a7`.
[Retirement](release-playback-attempt-1-retirement.json) verified its upload,
removed only uploaded evidence scratch, disabled workflow `416122134` and
removed unchanged QA head `92e7a583feb25e04331c47387cf75879ddde5325`. Its exact
ref was independently observed absent. Earlier capture/package/publication
scopes were not replayed. Local Guard remained refused at 2.8/34.0 GiB.
