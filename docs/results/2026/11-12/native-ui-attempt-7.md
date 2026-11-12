# Native UI attempt 7: expanded picker names absent

Last updated: 2026-11-12

[Run 43190175402](https://github.com/alvarovillalbaa/framelet/actions/runs/43190175402),
job 131087185668, failed FUI01 at source
`aba5c000707b67b865e0c0e8f2d19fe9566eb6f9`. The grounded arrow click satisfied
the explicit expanded-state assertion. The test then found no popup named
`Canvas`. The single failed verdict remains unchanged; no export or independent
post-export verification ran.

The [diagnostic screenshot](native-ui-attempt-7-diagnostic-final.png) was viewed.
The [native hierarchy](native-ui-attempt-7-diagnostic-final.accessibility) shows
disclosure value `1` and visible Canvas/Layout/Background captions. Their popup
controls expose only values `Landscape`, `Screen`, `Midnight`, without those
field names. The eighth source adds explicit accessible names to these three
observed controls without changing their visual labels, selection or layout.
The same test also checks that the Layout value remains Screen. This establishes
named-control coverage when it passes, not human VoiceOver acceptance.

The [complete receipt](native-ui-attempt-7.json) retains exact command streams,
original diagnostics, generated source media and saved partial edits. The
[complete log](native-ui-attempt-7.log.json) preserves original UTF-8 text.
Owned app/runner absence, equal source guards and owned library/scratch removal
passed. The [retirement receipt](native-ui-attempt-7-retirement.json) records
uploaded evidence verification, removed runner packet and exact temporary
control retirement. Previous failures, their distinct sources, and the
evidence-only archive remain preserved. Existing thirty-case/native packaging
results are not rerun or relabeled as this profile's result.
