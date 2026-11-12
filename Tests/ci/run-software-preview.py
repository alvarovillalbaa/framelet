"""Six read-only encoded-frame checks; no app, capture, export or old-case replay."""
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import selectors
import shutil
import signal
import stat
import subprocess
import tempfile
import time
import traceback
import uuid

source = os.environ["FRAMELET_SOURCE_COMMIT"]
assert re.fullmatch(r"[0-9a-f]{40}", source)
assert platform.system() == "Darwin" and platform.machine() == "x86_64"
assert os.environ["GITHUB_REPOSITORY"] == "alvarovillalbaa/framelet"
assert os.environ["GITHUB_REF"] == "refs/heads/qa/framelet-software-preview-20261112-4"
repo = Path.cwd().resolve()
parent = Path(os.environ["RUNNER_TEMP"]).resolve()
root = Path(tempfile.mkdtemp(prefix="framelet-software-preview-", dir=parent)).resolve()
identity = root.stat()
nonce = uuid.uuid4().hex
(root / "owner").write_text(nonce)
evidence = parent / ("framelet-software-preview-evidence-" + os.environ["GITHUB_RUN_ID"])
assert not evidence.exists()
evidence.mkdir(mode=0o700)
for folder in ("cache", "tmp", "source", "fixture"):
    (root / folder).mkdir(mode=0o700)
env = {key: os.environ[key] for key in ("PATH", "HOME", "LANG") if key in os.environ}
env.update(DEVELOPER_DIR="/Applications/Xcode_16.4.app/Contents/Developer", CI="true", GIT_OPTIONAL_LOCKS="0",
    TMPDIR=str(root / "tmp") + "/", CLANG_MODULE_CACHE_PATH=str(root / "cache/modules"),
    SWIFTPM_MODULECACHE_OVERRIDE=str(root / "cache/swiftpm"))
started = time.monotonic()
report = {"kind": "framelet-compatible-preview-files", "source": source, "status": "failed",
    "commands": [], "errors": [], "cleanup": {}, "storageSnapshots": [], "oldCasesReplayed": False,
    "applicationLaunched": False, "captureOrExportRequested": False,
    "nativeProfile": {"macOS": platform.mac_ver()[0], "architecture": platform.machine(), "Xcode": "16.4"}}
sha = lambda data: hashlib.sha256(data).hexdigest()
baseline = None
fixture_before = None
export = root / "source"
live_groups = set()
cleanup_phase = False


def storage(enforce=True):
    paths = [root, evidence] + list(root.rglob("*")) + list(evidence.rglob("*"))
    rows, links, invalid = [], [], []
    developer = Path(env["DEVELOPER_DIR"]).resolve()
    caches = (root / "cache", root / "tmp")
    for path in paths:
        try:
            value = path.lstat()
        except FileNotFoundError:
            if any(path.is_relative_to(cache) for cache in caches):
                continue
            raise
        row = {"path": str(path.relative_to(parent)), "bytes": value.st_size, "allocated": value.st_blocks * 512,
            "device": value.st_dev, "inode": value.st_ino, "mode": value.st_mode}
        if stat.S_ISLNK(value.st_mode):
            row["target"] = os.readlink(path)
            try:
                target = path.resolve(strict=True)
                row["resolvedTarget"] = str(target)
                row["admittedCompilerCacheAlias"] = any(path.is_relative_to(cache) for cache in caches) and (
                    any(target.is_relative_to(cache) for cache in caches) or target.is_relative_to(developer))
                row["targetMode"] = target.stat().st_mode
                row["admittedCompilerCacheAlias"] = row["admittedCompilerCacheAlias"] and (
                    stat.S_ISREG(row["targetMode"]) or stat.S_ISDIR(row["targetMode"]))
            except (OSError, RuntimeError):
                row["admittedCompilerCacheAlias"] = False
            links.append(row)
            if not row["admittedCompilerCacheAlias"]: invalid.append(row)
        elif not (stat.S_ISREG(value.st_mode) or stat.S_ISDIR(value.st_mode)):
            invalid.append(row)
        rows.append(row)
    unique = {(row["device"], row["inode"]): row for row in rows}
    apparent = sum(row["bytes"] for row in rows)
    allocated = sum(row["allocated"] for row in unique.values())
    snapshot = {"entries": len(paths), "apparent": apparent, "allocated": allocated,
        "compilerCacheAliases": links, "invalidEntries": invalid,
        "largest": sorted(rows, key=lambda row: row["bytes"], reverse=True)[:16]}
    assert len(report["storageSnapshots"]) < 256
    report["storageSnapshots"].append(snapshot)
    report["maximumApparentBytes"] = max(report.get("maximumApparentBytes", 0), apparent)
    report["maximumAllocatedBytes"] = max(report.get("maximumAllocatedBytes", 0), allocated)
    if enforce:
        assert len(paths) <= 16384 and len(links) <= 64 and not invalid, "Owned topology refused; snapshot retained"
        assert apparent <= 4 * 1024 ** 3 and allocated <= 4 * 1024 ** 3, "Owned storage exceeds 4 GiB; no sparse exception"


def group_members(pid, command):
    observed = subprocess.run(["/bin/ps", "-axww", "-o", "pid=,pgid=,uid=,command="], capture_output=True, timeout=5)
    assert observed.returncode == 0 and len(observed.stdout) <= 4 * 1024 ** 2 and len(observed.stderr) <= 65536
    rows = []
    for line in observed.stdout.decode().splitlines():
        parts = line.strip().split(None, 3)
        if len(parts) == 4 and all(value.isdecimal() for value in parts[:3]) and int(parts[1]) == pid:
            assert len(parts[3]) <= 8192
            rows.append({"pid": int(parts[0]), "group": int(parts[1]), "uid": int(parts[2]), "command": parts[3]})
    assert len(rows) <= 64
    snapshots = report.setdefault("processGroupObservations", [])
    assert len(snapshots) < 256
    snapshots.append({"command": command, "group": pid, "members": rows, "monotonic": time.monotonic(),
        "psStdoutBytes": len(observed.stdout), "psStdoutSHA256": sha(observed.stdout)})
    return rows


def run(name, args, seconds=120, cwd=None, enforce_storage=True):
    deadline = min(started + (580 if cleanup_phase else 540), time.monotonic() + seconds)
    assert time.monotonic() + 1 < deadline
    child = subprocess.Popen(args, cwd=cwd or repo, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    live_groups.add(child.pid)
    selector = selectors.DefaultSelector()
    for label, stream in (("stdout", child.stdout), ("stderr", child.stderr)):
        os.set_blocking(stream.fileno(), False); selector.register(stream, selectors.EVENT_READ, label)
    streams = {key: bytearray() for key in ("stdout", "stderr")}
    observed = {key: [0, hashlib.sha256()] for key in streams}
    eof = set(); signals = []; error = None
    sampled = 0
    inspection_errors = []
    absent = False

    def drain(wait):
        for event, _ in selector.select(wait):
            data = os.read(event.fileobj.fileno(), 65536)
            label = event.data
            if not data:
                eof.add(label); selector.unregister(event.fileobj)
            else:
                observed[label][0] += len(data); observed[label][1].update(data)
                room = 2 * 1024 ** 2 - len(streams[label]); streams[label].extend(data[:room])
                if len(data) > room:
                    raise AssertionError("Command stream bound")

    try:
        while selector.get_map():
            if time.monotonic() - sampled >= 5:
                storage(enforce_storage); sampled = time.monotonic()
            assert time.monotonic() < deadline, "Command deadline"
            drain(0.1)
        child.wait(timeout=5)
    except BaseException as caught:
        error = caught
    finally:
        # Read metadata, never probe permission with killpg(..., 0). Signal only
        # while the original owned child is still live and every member has our UID.
        try:
            if child.poll() is None and error is None:
                try: child.wait(timeout=2)
                except subprocess.TimeoutExpired: pass
            if child.poll() is None:
                members = group_members(child.pid, name)
                assert members and any(row["pid"] == child.pid for row in members)
                assert all(row["uid"] == os.getuid() for row in members), "Group ownership unknown; no signal"
                if child.poll() is None:
                    os.killpg(child.pid, signal.SIGTERM); signals.append("SIGTERM")
                until = time.monotonic() + 3
                while child.poll() is None and time.monotonic() < until:
                    try: drain(0.1)
                    except BaseException: pass
                if child.poll() is None:
                    members = group_members(child.pid, name)
                    assert members and all(row["uid"] == os.getuid() for row in members)
                    if child.poll() is None:
                        os.killpg(child.pid, signal.SIGKILL); signals.append("SIGKILL")
                child.wait(timeout=3)
            until = time.monotonic() + 3
            members = group_members(child.pid, name)
            while members and time.monotonic() < until:
                time.sleep(0.1); members = group_members(child.pid, name)
            absent = not members
        except BaseException:
            inspection_errors.append(traceback.format_exc())
        child.poll()
        try:
            until = time.monotonic() + 2
            while selector.get_map() and time.monotonic() < until:
                try: drain(0.1)
                except BaseException: pass
        except BaseException:
            inspection_errors.append(traceback.format_exc())
        child.poll()
        selector.close()
        for stream in (child.stdout, child.stderr): stream.close()
        if absent: live_groups.discard(child.pid)
        row = {"name": name, "args": args, "exitCode": child.returncode, "signals": signals,
            "error": str(error) if error else None, "ownershipInspectionErrors": inspection_errors,
            "ownedGroupAbsent": absent, "streams": {}}
        for label, data in streams.items():
            raw = bytes(data)
            row["streams"][label] = {"bytes": len(raw), "sha256": sha(raw), "eof": label in eof,
                "complete": label in eof and len(raw) == observed[label][0], "observedBytes": observed[label][0],
                "observedSHA256": observed[label][1].hexdigest(),
                "gzipBase64": base64.b64encode(gzip.compress(raw, mtime=0)).decode()}
        report["commands"].append(row)
    if error is not None: raise error
    assert child.returncode == 0 and absent and not inspection_errors and all(s["complete"] for s in row["streams"].values()), name + " failed"
    return bytes(streams["stdout"])


def source_guard():
    rows = []
    raw = run("source-guard", ["git", "ls-tree", "-r", "--full-tree", "HEAD"], enforce_storage=False)
    for line in raw.decode().splitlines():
        meta, name = line.split("\t", 1)
        mode, kind, blob = meta.split()
        path = repo / name
        assert kind == "blob" and mode in ("100644", "100755") and path.is_file() and not path.is_symlink()
        assert path.stat().st_size <= 4 * 1024 ** 2 and bool(path.stat().st_mode & 0o111) == (mode == "100755")
        data = path.read_bytes()
        assert hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest() == blob
        rows.append({"path": name, "mode": mode, "blob": blob, "bytes": len(data), "sha256": sha(data)})
    report.setdefault("sourceGuards", []).append(rows)
    return rows


def fixture_snapshot(package):
    paths = list(package.rglob("*"))
    assert len(paths) == 4 and all(not p.is_symlink() for p in paths)
    files = [p for p in paths if p.is_file()]
    assert len(files) == 3 and sum(p.stat().st_size for p in files) < 65536
    return {str(p.relative_to(package)): {"bytes": p.stat().st_size, "sha256": sha(p.read_bytes())} for p in files}


try:
    assert run("head", ["git", "rev-parse", "HEAD"]).decode().strip() == source
    assert not run("status", ["git", "status", "--porcelain", "--untracked-files=all", "--ignored"]).strip()
    run("toolchain", ["/usr/bin/xcodebuild", "-version"])
    baseline = source_guard(); index_before = sha((repo / ".git/index").read_bytes())
    changed = run("protected-input-diff", ["git", "diff", "--name-only", "9909bf8845d10c2965e6dd07549b6c5f38958bb6", "HEAD",
        "--", "Package.swift", "Sources", "Resources", "script", "Tests/FrameletCoreTests", "Tests/FrameletPlaybackTests",
        "Tests/FrameletAcceptance.xcodeproj", "Tests/e2e", "Tests/ci/ReleasePlaybackPixels.swift", "Tests/ci/SoftwarePreviewFiles.swift"])
    assert set(changed.decode().splitlines()) == {"Sources/Framelet/Services/SoftwareRecordingCompositor.swift"}
    report["previewModelAndCasesUnchangedFromAttempt3"] = True
    report["compositorChanges"] = "Correct native crop/opacity argument labels and Sendable dictionary value types only"
    compile_paths = [row for row in baseline if row["path"].startswith("Sources/FrameletCore/") or row["path"] in (
        "Sources/Framelet/Services/RecordingComposition.swift", "Sources/Framelet/Services/ExportGeometry.swift",
        "Sources/Framelet/Services/ExportCoordinator.swift", "Sources/Framelet/Services/SoftwareRecordingCompositor.swift",
        "Tests/ci/SoftwarePreviewFiles.swift")]
    assert len(compile_paths) == 8
    for row in compile_paths:
        path = export / row["path"]; path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes((repo / row["path"]).read_bytes())
    seed = repo / "docs/results/2026/11-12/capture-attempt-4-files/library/Recordings/4A689114-5E06-43A3-AE28-BD9B9FDB524E.framelet"
    pins = {"manifest.json": "618cc4de511ee689fa5725a789af4e2bc9601ba65a50eb0d6cd4974cf642e80c",
        "segments/C456C486-F99C-498F-9ACE-7BBB746813A9-screen.mp4": "a255cd9c0d2fd723c28d1b48794ff47cf2b5b4d3a57de2eb7fd18c08b723f329",
        "segments/112458AE-5A21-4B59-A225-6466A4AE91D3-screen.mp4": "eae605da7fa85a55ab5c5a5be0dc2eb1e67e04f15b556173079b47e0d9767c91"}
    package = root / "fixture" / seed.name
    for name, digest in pins.items():
        path = seed / name
        assert path.is_file() and not path.is_symlink() and path.stat().st_size < 65536
        data = path.read_bytes(); assert sha(data) == digest
        destination = package / name; destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("xb") as stream: stream.write(data)
    fixture_before = fixture_snapshot(package); report["fixtureBefore"] = fixture_before
    common = ["/usr/bin/xcrun", "swiftc", "-parse-as-library", "-swift-version", "5", "-target", "x86_64-apple-macos15.0",
        "-module-cache-path", str(root / "cache/modules")]
    core = sorted((export / "Sources/FrameletCore").glob("*.swift")); assert len(core) == 3
    run("core-compile", common + ["-module-name", "FrameletCore", "-emit-module", "-emit-object", "-whole-module-optimization",
        "-emit-module-path", str(root / "cache/FrameletCore.swiftmodule"), *map(str, core), "-o", str(root / "cache/FrameletCore.o")])
    executable = root / "software-preview-files"
    run("pixel-check-compile", common + ["-I", str(root / "cache"), str(root / "cache/FrameletCore.o"),
        *[str(export / row["path"]) for row in compile_paths if not row["path"].startswith("Sources/FrameletCore/")],
        "-o", str(executable)])
    report["pixelChecks"] = json.loads(run("six-encoded-frame-cases", [str(executable), str(package), str(evidence / "frames")], seconds=180))
    assert report["pixelChecks"]["verified"] is True and report["pixelChecks"]["caseCount"] == 6 and report["pixelChecks"]["frameCount"] == 8
except BaseException:
    report["errors"].append(traceback.format_exc())
finally:
    cleanup_phase = True
    safe = False
    source_ok = baseline is None
    fixture_ok = fixture_before is None
    try:
        if baseline is not None:
            assert source_guard() == baseline and sha((repo / ".git/index").read_bytes()) == index_before
            report["cleanup"]["sourceAndIndexUnchanged"] = True
            source_ok = True
    except BaseException:
        report["errors"].append(traceback.format_exc())
    try:
        if fixture_before is not None:
            report["fixtureAfter"] = fixture_snapshot(package)
            assert report["fixtureAfter"] == fixture_before
            report["cleanup"]["fixtureUnchanged"] = True
            fixture_ok = True
            report["retainedFixtureInputs"] = [{"name": str(p.relative_to(package)), "bytes": p.stat().st_size,
                "sha256": sha(p.read_bytes()), "gzipBase64": base64.b64encode(gzip.compress(p.read_bytes(), mtime=0)).decode()}
                for p in sorted(package.rglob("*")) if p.is_file()]
    except BaseException:
        report["errors"].append(traceback.format_exc())
    try:
        storage(False)
        for pid in list(live_groups):
            if not group_members(pid, "final-read-only-cleanup"):
                live_groups.discard(pid)
        report["cleanup"]["unsettledGroups"] = sorted(live_groups)
        assert not live_groups and time.monotonic() - started < 580
        report["cleanup"]["allOwnedGroupsAbsent"] = True
        safe = source_ok and fixture_ok
    except BaseException:
        report["errors"].append(traceback.format_exc())
    try:
        images = []
        if (evidence / "frames").exists():
            paths = list((evidence / "frames").iterdir())
            assert len(paths) <= 8 and all(p.is_file() and not p.is_symlink() and re.fullmatch(r"[0-9]{2}-[a-z-]+\.png", p.name) for p in paths)
            total = 0
            for path in sorted(paths):
                raw = path.read_bytes(); total += len(raw)
                assert len(raw) <= 2 * 1024 ** 2 and total <= 16 * 1024 ** 2
                images.append({"name": path.name, "bytes": len(raw), "sha256": sha(raw),
                    "gzipBase64": base64.b64encode(gzip.compress(raw, mtime=0)).decode()})
        report["renderedImages"] = images
        if report.get("pixelChecks"):
            assert {p["name"]: p["sha256"] for p in images} == {p["name"] + ".png": p["sha256"] for p in report["pixelChecks"]["frames"]}
    except BaseException:
        safe = False; report["errors"].append(traceback.format_exc())
    try:
        assert safe and root.parent == parent and not root.is_symlink()
        current = root.stat()
        assert (current.st_dev, current.st_ino) == (identity.st_dev, identity.st_ino) and (root / "owner").read_text() == nonce
        shutil.rmtree(root); assert not root.exists()
        report["cleanup"]["ownedRootAbsent"] = True
    except BaseException:
        report["errors"].append(traceback.format_exc())
    report["elapsedSeconds"] = time.monotonic() - started
    if report.get("pixelChecks", {}).get("verified") and not report["errors"]:
        report["status"] = "passed"
    raw = json.dumps(report, separators=(",", ":")).encode()
    assert len(raw) <= 48 * 1024 ** 2
    (evidence / "receipt.json").write_bytes(raw)
    print("FRAMELET_SOFTWARE_PREVIEW_RESULT=" + base64.b64encode(gzip.compress(raw, mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
