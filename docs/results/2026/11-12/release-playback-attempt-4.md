# Playback advanced; viewport assertion failed and rendered frames were black

12 November 2026. [Run 43243509981](https://github.com/alvarovillalbaa/framelet/actions/runs/43243509981),
job `131269949630`, failed FUI04 at source
`690cd777cff80a2d9ef11065bd6f6dc83108d85c`. Native head
`35eca82bef390f6270f37ece4da2b81b5b0436a9` matches tree
`afb6518d2d65b6f007f0f7af98612225b4fb3586`. The actual profile was Xcode 16.4,
macOS 15.7.9/x86_64, the exact unchanged 0.1.3 Release app and Debug UI harness.

The case reached play/pause, a three-second frozen playhead, continuous playback
across the real take boundary and both global seeks. Five original phase PNG/AX
pairs and partial progress were retained. Phase times were 0:00, 0:05, 0:15,
0:04 and 0:16 of 0:23. Actual app PID `3000` matched the extracted Release
executable; no observed Debug app was accepted. These are partial native
observations, not a passed playback verdict.

After selecting clip two, `showPreview()` broke its scroll loop as soon as the
play button was hittable, then failed the stricter viewport-containment
assertion at line 69. The original final PNG shows the scope above the clipped
detail viewport. A changed helper must require contained scope/time frames in
the loop condition while preserving those postconditions and the complete case.

Separately, visual inspection of the original red-playback, boundary-blue and
final diagnostic PNGs shows a black preview despite the advancing clock.
The full independent nine-color verifier did not run because the native case
failed. Do not infer working rendered video from the partial clock behavior,
or infer a product defect versus VM/screenshot behavior without a control.
The next candidate keeps the released bundle and full pixel assertions intact
and adds a bounded first-party read-only rendering diagnostic after normal
product Quit, using only these already-authored media files.

All fifteen commands/30 original complete EOF streams, 22 inline attachments
and four authored inputs were independently decoded and byte/hash checked.
Both 412-file source vectors and index match; released bundle and library bytes
are unchanged. No-source/disabled-Start acknowledgment preceded ordinary app
termination. Owned app/runner, library and root cleanup passed. Maximum unique
allocated bytes were 414,908,416; maximum apparent bytes 27,193,622,055 under the
three-leaf sparse-cache exception. Elapsed time was 249.029 seconds.

[Raw receipt](release-playback-attempt-4.json): 2,652,888 bytes, SHA-256
`19c552a878edf79489f54baccacdbe1e7b63355995064212f992b14a5017816b`.
The [lossless job log](release-playback-attempt-4.log.json), original PNG/AX and
progress/shutdown attachments preserve the failure. Artifact `13956677143` is
60,841,237 bytes, SHA-256
`6fb6db00fc0ff1d8e9c0f7818778f9295384aa8c0adbac3c89358232375d604e`.
[Retirement](release-playback-attempt-4-retirement.json) verified upload,
removed uploaded scratch, disabled workflow `416164380` and removed unchanged
QA head `7e13607a5b378312329e3fcb0061b33213ed58f6`. Its exact ref was independently
read back absent. All three earlier failures remain unchanged.
