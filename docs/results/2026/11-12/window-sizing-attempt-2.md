# FUI02 attempt 2: additional-window vertical overflow

12 November 2026. [Run 43201465559](https://github.com/alvarovillalbaa/framelet/actions/runs/43201465559),
job 131125684590, failed the complete FUI02 case at source
`9db3539173a505cd448bea6f51121215c67348c3`. Compilation/signing passed. Native
first launch and relaunch satisfied their full frame/preview assertions, with
windows `(0,25,1024,681)`. This remains a failed case, not partial acceptance.

The additional window really opened. The [viewed failure screenshot](window-sizing-attempt-2-diagnostic-final.png)
and [original hierarchy](window-sizing-attempt-2-diagnostic-final.accessibility)
show both windows: the first remains 681 points tall, while the new window is
684. The [contemporaneous display metadata](window-sizing-attempt-2-diagnostic-display.json)
records usable bounds `(0,25,1024,681)`. The native wait therefore correctly
rejected the new window's three-point vertical overflow. This is a product
placement issue; the count/selector worked. Its internal rounding/layout cause
has not been proven.

The third candidate adds a twelve-point vertical inset at each edge of the
selected display's usable area before clamping preferred placement. It keeps
horizontal sizing, 600-point minimum content height, native resizing/restoration,
the same live-metadata checks and one-point containment tolerance. Do not
weaken the check or combine phases from different attempts into acceptance.

The [complete receipt](window-sizing-attempt-2.json),
[lossless log](window-sizing-attempt-2.log.json), and
[retirement receipt](window-sizing-attempt-2-retirement.json) retain originals,
including first/reopened PNG/AX, the failure PNG/AX, display metadata and fixture
state. All four owned cleanup flags passed. Artifact 13934938897 is 94,939,949
bytes, SHA-256 `9d0589f70c90b2a8914be40d740af286ae851f20b54dbf07fb28331313b54ac5`.
Workflow 415863755 was disabled and its exact QA head removed. Earlier native,
pixel, packaging and public release results were not replayed or relabeled.
