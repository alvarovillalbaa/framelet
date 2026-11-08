# Preview packaging attempt 1 — metadata API refused before build

8 November 2026. [Run 42469094734](https://github.com/alvarovillalbaa/framelet/actions/runs/42469094734),
job `128695411198`, checked source
`259b9e3803080bda1aa8a7c7f32ab53f0426d655` under workflow
`74ce756f10577a20cee1eddc9af5c3de9edfb989`.

The original verdict is **failed**, error
`module 'os' has no attribute 'listxattr'`. CPython's
[documented `os` extended-attribute API](https://docs.python.org/3.12/library/os.html#linux-extended-attributes)
is Linux-specific; this Mac runner does not expose it. The controller used
it during its first owned-root snapshot. Source review missed that portability
boundary. This is an observed metadata-inspector failure, without evidence of
an application, compiler, archive or fixture defect.

The native source/index guard bound 60 files / 405,463 bytes. Job provisioning
reports macOS 15.8.2, image `macos-15-arm64` / `20261104.0514.1`; no toolchain
version command ran. **Zero recorded commands, builds, tests, app launches,
captures or packaging checks ran.** No preview archive was created or released.
The old 30-case profile stays closed and separate.

**Owned cleanup is unverified:** its snapshot failed on the same missing API.
The private root had been created, but no exact deleted/remaining inventory or
root path survived in the receipt. Zero resource peaks are unobserved samples,
not proof of zero scratch usage. No later control may retroactively turn this
teardown into a pass. Controller elapsed was 0.264 seconds; no owned signals.

Workflow `411036460` was disabled; QA1 was retired at
`84eda588ae8ec532fa4bf7c9e8f6e0121ec3aa04`. The old completed test workflow
`399969674` is separately disabled. A changed control may use the documented
macOS read-only native extended-attribute APIs through Python's standard
library, preserving no-follow semantics and finite allocation/errno checks.
Apple documents the native [name-list call](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/listxattr.2.html)
and [value read](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/getxattr.2.html)
separately from Python's Linux-only convenience functions.
The builder/application inputs stay unchanged; all packaging acceptance must
execute afresh. No new dependency, app/device action, paid service or local
runtime exception is needed.

| Immutable original | Bytes | SHA-256 |
| --- | ---: | --- |
| [Receipt](preview-package-attempt-1.json) | 13,168 | `bf2c52f98db533ffcc739d96a1df368e6e54d79b4195bf561360fafe16acd7e8` |
| [Full job log](preview-package-attempt-1.log) | 30,248 | `364225733db36ab0dda1f7c43f4cdfff752a1685ed81215fbfe2022eb0bf0951` |

The receipt is the exact result-line JSON plus newline. Preserve both bytes
and the original failed verdict. The [scope](../../../proposals/preview-package-checks.md)
separates source inspection, new universal packaging, earlier tests and full
native/trusted-distribution acceptance.
