# Player-output diagnostic passed; composed buffers are absent

12 November 2026. [Run43282504000](https://github.com/alvarovillalbaa/framelet/actions/runs/43282504000),
job131407203013, passed at source `a71ae164463105a5d4fbdedc694a74e370ee74f2`.
Native head `9e36873b669a21a1b29bcf597e3ca2486f57d652` matches tree
`485d4b04a884dc34f9d869316cf053ba88909f5d`. Xcode16.4/macOS15.7.9/x86_64.
One new FUI04O case only; no product or old native case launched.

Both original red/blue native screenshots and both raw-control output PNGs were
visually inspected. Production-compositor plain views and the experimental
IOSurface/Metal pool view stay black. The copied-buffer NSImageView stays empty:
the composed player produced no copied buffers during the sampling windows.
The instrumented pool wrapper recorded zero start requests at both observations,
despite ready player/item statuses, advancing clocks and no player/item errors.
Changing presentation alone or adding pool requirements is not a supported fix.

The raw assembled-asset video-output control returned actual640×428 BGRA buffers:
red read-only median `[224,21,12]`, blue `[26,46,231]`, with successful locks and
IOSurface backing. Core Image conversion produced `[222,40,6]` and `[40,61,235]`.
Actual display times4.8133s/15.1533s matched the red/blue phases. Its original
PNGs contain the authored header and expected colors. This validates the pull/
pixel-reading method on this profile, without qualifying composed playback.

Actual helper PID4229 matched AX, Bundle path and independent canonical libproc
observations. Helper executable833,360 bytes/SHA-256
`17313dcff57ad9370501cd23b202cf16d5e18143f92a37ecb3da9c1e23416317`
stayed unchanged. Both measured windows and all panels were fully on-screen;
the helper was active. The default product library stayed absent.

All16 commands/32 original complete EOF streams, seven native attachments,
four output files, four exact copied fixture files and two equal590-file source
vectors/index were independently decoded and byte/hash checked against the
reviewed native Git tree. Unused0.1.4 bundle and helper hashes stayed unchanged.
Acknowledged read-only shutdown, no unexpected product, all owned groups/app/
runner/fixture/root absence passed. No signals or ownership-inspection errors.
Recorded maxima27,235,068,471 apparent/468,697,088 allocated bytes obey the
explicit three-leaf sparse exception; elapsed212.553s. No local heavy execution,
capture/export/device/permission, paid service, dependency or model action.

[Raw receipt](player-output-attempt-1.json):1,026,276 bytes/SHA-256
`303bfc16660fc698311432e06d62ce105bdcea1a9e1452e87d803abd9d3fca40`.
[Lossless logs](player-output-attempt-1.log.json), [original native images](player-output-attempt-1-files/diagnostic-output-red.png)
and [raw control frames](player-output-attempt-1-files/red-raw.png) are retained.
[Artifact](player-output-attempt-1-artifact.json)13973622379:1,340,742 bytes,
SHA-256 `2843694f18045a242365fe22b20c869abdb6da147f2b52d22039d86b6a3e5173`.
[Retirement](player-output-attempt-1-retirement.json) passed; eight API calls/
16 complete original streams verified. Current-run collection metadata admitted
the artifact, uploaded scratch removed, workflow416399644 observed disabled and
exact head `503ac4f41d588407989ee8af171bf2c4eccecb0b` deleted. Independent exact
ref readback returned no refs. Retirement SHA-256:
`b5c9b9f3edc9bb6bad3c073ee99ca4b25b91fe7921772e6c9481e7f1191d52a4`.

This diagnostic is closed. Do not replay its four panes or old composition/file/
native cases routinely. The full0.1.4 product result remains failed and public
0.1.3 unchanged. The six earlier ImageGenerator cases prove decoded outputs and
compositor-instance creation; they did not count rendering callbacks.

Next isolate instruction scheduling/validation and source-track delivery before
another shipping edit. Apple documents that a valid
[passthrough track bypasses the compositor](https://developer.apple.com/documentation/avfoundation/avvideocompositioninstructionprotocol/passthroughtrackid),
and [required source IDs control composition inputs](https://developer.apple.com/documentation/avfoundation/avvideocompositioninstructionprotocol/requiredsourcetrackids).
Those are hypotheses to measure, not an established cause. Record actual
instruction properties and validation, then use an explicit protocol/callback
control if justified. No GPU-absence, physical-Mac, performance or repair claim.
