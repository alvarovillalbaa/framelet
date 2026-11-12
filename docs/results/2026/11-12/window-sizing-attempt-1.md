# FUI02 attempt 1: first-window height outside admitted bounds

12 November 2026. [Run 43199376840](https://github.com/alvarovillalbaa/framelet/actions/runs/43199376840),
job 131118471917, failed the single FUI02 case at source
`59d6b7b6c291f8e3b767115b098da96f1c808821`. App/helper compilation and signing
passed. The native case stopped at its first frame-containment wait, before
relaunch or additional-window phases. No window-repair acceptance is claimed.

The host admitted a 1024×768 display with usable rectangle `(0,25,1024,681)`
before app launch. The [viewed original screenshot](window-sizing-attempt-1-diagnostic-final.png)
and [native hierarchy](window-sizing-attempt-1-diagnostic-final.accessibility)
record a window `(0,25,1024,692)`. The original 640-point content minimum plus
52-point window chrome requires 692 points, exceeding the admitted 681. The
pre-launch metadata alone does not establish whether the Dock's usable region
remained identical during the assertion. Both observations are preserved;
do not relabel this failed case as passing.

The changed candidate reduces the content minimum to 600, leaving space for
chrome, and records live single-display usable bounds separately at each native
phase. Strict containment and unchanged resolution remain required. The UI
runner uses only public AppKit display metadata, native window observations and
its bundled config; no new file rights, capture API or permission prompt.
Its failure teardown also retains contemporaneous display metadata.

The [complete receipt](window-sizing-attempt-1.json),
[lossless job log](window-sizing-attempt-1.log.json), and
[retirement receipt](window-sizing-attempt-1-retirement.json) retain originals.
All 40 complete command streams were independently decoded and hash-verified.
Source guards and four owned cleanup checks passed. Uploaded artifact
13934438486 is 91,885,053 bytes, SHA-256
`7831336a63e8126e360b01d4fd51da406cee72b80d2efcece525b204a9bb493b`.
Workflow 415850791 is disabled and its exact QA head retired. The 0.1.1 release,
FUI01, earlier thirty cases and packaging evidence keep their original results;
none was replayed or replaced here.
