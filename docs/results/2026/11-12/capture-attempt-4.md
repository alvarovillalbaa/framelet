# Actual silent window capture, pause, reopen and export passed

12 November 2026. The complete FUI03 case and independent file verifier passed
in [run 43229159530](https://github.com/alvarovillalbaa/framelet/actions/runs/43229159530),
job `131219651032`, at source `e1c3b5ea9013630375a9d5b29b7749784255d504`.
Native source `304f11a9273d9f0cacbc0d906531cf6931133628` has the same tree
`dd226887785d53209239d20a079abb2f6fe3a787`. This was Xcode 16.4,
macOS 15.7.9/x86_64 Debug on `macos-15-intel`, not a local execution.

The real OS picker selected only the nonce-titled AppKit fixture. Framelet's
chosen-filter title matched before Start. Camera, microphone and system audio
remained off. Actual ScreenCaptureKit red/blue takes, foreground Pause/Resume/
Stop, hidden library during both takes, normal Quit, explicit Window-menu
restoration and the native save-panel export all passed together. One native
case passed, with zero failures, skips or expected failures. The three earlier
failed cases remain preserved and were not reclassified.

Independent AVFoundation inspection found one video track and no audio in
each original and the export. The 640×428 takes lasted 10.328333333333333 and
12.751666666666667 seconds. The 1920×1080 export lasted exactly their 23.08-second
sum, excluding the deliberately observed 7.190186618999974-second pause.
Decoded export centers were red `[222,40,6]` then blue `[39,61,235]`.
The 801,717-byte export SHA-256 is
`367d5616d03e0e54f767140cb14b302da1128fb901d4d5dbae76c280de8da074`.

The read-only observer completed normally, hashing at uptime 519.964230712,
after Stop was requested and before Export at 547.716823459. Both original
hashes and the manifest still match the independently expanded retained bytes.
All 42 command streams, both observer streams, 24 inline attachments and seven
authored files were decoded and byte/hash checked. All nine original phase
PNGs were viewed. Both 338-file source vectors match. The receipt reports no
old-case replay, native writer-group signal or camera/audio permission action.

The actual Stop/ready/source-control acknowledgment and settled export preceded
ordinary termination and cleanup. Owned app/runner, fixture, library and root
absence passed. Only the passing raw xcresult intermediate was removed after
full verdicts; original streams, media, manifest, PNGs, AX trees and identities
remain in [the original receipt](capture-attempt-4.json),
[lossless job log](capture-attempt-4.log.json), and
[authored files](capture-attempt-4-files/).
Receipt SHA-256: `35f72c68055354af80f72eccd612fa3017a962f3b09bdbe66f7ef23028d87ff9`.

Artifact `13949337922` is 5,725,314 bytes, SHA-256
`db342d51aad0c4fd63f715b96208212e2a529718b2632980728e1ec962fccba9`.
The [retirement receipt](capture-attempt-4-retirement.json) binds its upload to
this exact run/head, removes only uploaded scratch, disables workflow
`416066672` and removes unchanged QA head
`9c332147c24dd374f2c431b6667b0d9e652b70db`. The exact branch was independently
observed absent. Main has no active workflow file.

FUI03's basic silent-window path is closed at this source. Do not replay it as
routine follow-up. The selected-window naming change can now enter a separate
non-launching universal preview refresh. First-complete-screen-callback versus
first encoded-sample timing, camera/audio synchronization, actual preview
playback of this capture, physical/multiple/rotated displays, migration, human
accessibility and trusted downloaded-app launch remain unverified. Local
Storage Guard refusal remained respected. This does not complete the full
recorder or portfolio goal.
