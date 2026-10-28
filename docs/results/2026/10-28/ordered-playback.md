# Ordered recording preview source

28 October 2026. Source-only progress from clean Framelet
`9bb8e8399da3f713d2371037f7f33c05843b7644`. Native compilation, playback,
media generation, tests and app execution remain unverified.

## Requirement and change

The [product contract](../../../specs/recorder.md) requires recording playback
and ordered concatenated clips. The existing clip editor also said clips play
and export in that order. At the inspected baseline, the player loaded only
one selected slice, used its duration and stopped there; the preview explicitly
described selected-clip-only playback. This was source evidence of a missing
whole-edit flow, not an observed native failure.

The editor now defaults to **Recording** with one global playback cursor across
the ordered, trimmed edit. **Selected Clip** preserves individual audition.
Preview and export share `RecordingCompositionBuilder`, extracted from the
existing export assembly. Both receive the same range insertion, orientation,
canvas, camera-gap instructions and source audio mix. Preview displays the
assembled canvas once, retains its source assets and writes no media. Export
keeps its destination checks, owned staging, exclusive commit and originals.

The view's immutable task identity includes the project snapshot, package,
scope, capture state and explicit retry. Selecting another clip while in
Recording mode does not reload the edit. Editing, changing scope or capture
suspension clears the former item; loads never autoplay. Model generations and
seek requests fence late acknowledgements. Seek completion follows the current
play intent, so Pause during a seek cannot resume it. End callbacks consult the
configured native end boundary; periodic updates read the current player clock.
Fatal status/seek failures clear pending state and expose **Reload Preview**.

Independent source readback identified and corrected three lifecycle edges:
an interrupted seek leaving a playing flag, an old end/time callback applying
after a newer seek, and a screen failure hidden by an outstanding camera load.
A source counterexample also tightened end handling to the configured rounded
item boundary. These are reviewed source fixes; no native failure/pass is
claimed. Native asset operations may acknowledge later; the generation fence
prevents their obsolete item/state publication rather than claiming preemption.

## Prepared acceptance and limits

The [new proposal](../../../proposals/ordered-playback-checks.md) covers a
compile/package check and exactly thirty authored cases: eighteen unchanged
core cases, six real composition cases and six real muted-player cases. New
fixtures generate small solid-colour media in private disposable custom
libraries; they do not use existing user files, screens or devices. The new
SwiftPM test target depends only on this package's existing modules. Its
workflow remains an inactive example outside `.github`.

Local Storage Guard reported **14.0 GiB free against 34.0 GiB required**. No
local install, build, typecheck, test, synthetic-media generation, native player,
app launch or UI automation was attempted. Only source parsing and bounded
reference/hash/whitespace inspection are permitted here. The
[source seal](ordered-playback-source.json) freezes the actual source, cases,
build inputs and proposal before any approval request.

Existing Apple Swift 6.3.3 parsed all 32 Swift manifest/source/test files with
zero diagnostics. Ruby parsed the inactive YAML, `bash -n` accepted its five
shell blocks, and Python parsed its three embedded Python blocks without
executing them. The five original core source/test files remain byte-identical
to the inspected baseline, preserving all eighteen core cases. Static native
header readback corrected the new checks to require actual composition-track
subclasses before inspecting their source segments. Final source inspection
finds exactly six composition and six player cases; none has run.

The sealed-source review matched all 44 input hashes, 38 build-input paths and
30 source registrations, resolved twelve local Markdown links and passed
whitespace checks, including new files. Export error definitions, path guards,
staging/exclusive commit and the monitor/cancellation/export tail matched the
baseline by source comparison. Independent fixture/suite readback found no
further concrete blocker. Its limits remain explicit: cancellation is probed
at partial/final progress, while the stale-seek case observes 200 ms stability
without independently acknowledging delivery of the old callback.

The shared assembly preserves existing export semantics by source comparison;
that is weaker than export playback proof. Camera synchronization retains the
explicit screen-anchor/encoded-frame assumption in the product contract.
Real capture, permission behavior, audio quality, UI accessibility, actual
export playback, trusted distribution and the full portfolio goal remain open.
No Vercel, Supabase, account, provider, paid plan or external dependency is
needed for this native source feature.
