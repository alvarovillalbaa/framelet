# Native UI attempt 6: disclosure click landed in padding

Last updated: 2026-11-12

[Run 43188747885](https://github.com/alvarovillalbaa/framelet/actions/runs/43188747885),
job 131082419928, failed FUI01 at source
`7239bbef6693ccd89e48fde23ffa487a555f846d`. The original edit actions completed,
then the new explicit disclosure-state wait timed out. The native case remains
failed; it did not query an expanded Canvas picker or export/reopen. Its
[complete receipt](native-ui-attempt-6.json) retains the exact native result,
command streams, original diagnostic attachments and generated library state.

The [diagnostic screenshot](native-ui-attempt-6-diagnostic-final.png) was viewed.
Its [native tree](native-ui-attempt-6-diagnostic-final.accessibility) still has
disclosure value `0`. The accessibility bounds start at x=263 with width 192.5,
but the visible arrow is inset around x=289. The prior normalized x=0.03 target
lands near x=269, in padding to the arrow's left. The changed seventh input
uses x=0.14 within those observed bounds (around x=290), preserving the same
explicit expanded-state assertion and full independent export verifier.
This is a grounded target correction, not random coordinates or an app fix.

The new teardown callback captured the failed UI and terminated Framelet even
when XCTest stopped at the assertion. The repaired observer indexed the
4,487,422-byte automatic video without rejecting it, retaining bounded PNGs and
trees inline. All original exported attachments remain in the uploaded artifact.
Owned app/runner absence, unchanged source and owned library/scratch removal
passed. The raw passing-result cleanup path was not entered. All application
inputs remain identical to the fifth source; old accepted tests/package are not
rerun. Earlier failures and the separate no-replay recovery remain preserved.
