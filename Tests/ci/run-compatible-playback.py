"""FUI04: exact compatible Release playback; no closed diagnostics or capture."""
import base64
import copy
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import platform
import plistlib
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
import zipfile

source = os.environ["FRAMELET_SOURCE_COMMIT"]
assert re.fullmatch(r"[0-9a-f]{40}", source)
assert platform.system() == "Darwin" and platform.machine() == "x86_64"
assert os.environ["GITHUB_REPOSITORY"] == "alvarovillalbaa/framelet"
assert os.environ["GITHUB_REF"] == "refs/heads/qa/framelet-compatible-playback-20261112-1"
PACKAGE_RECEIPT_SHA256 = "PENDING_PASSED_PACKAGE_RECEIPT"
assert re.fullmatch(r"[0-9a-f]{64}", PACKAGE_RECEIPT_SHA256), "Inactive until exact package evidence is reviewed"
repo = Path.cwd().resolve()
parent = Path(os.environ["RUNNER_TEMP"]).resolve()
root = Path(tempfile.mkdtemp(prefix="framelet-compatible-playback-", dir=parent)).resolve()
root_identity = root.stat()
nonce = uuid.uuid4().hex
(root / "owner").write_text(nonce)
evidence = parent / ("framelet-compatible-playback-evidence-" + os.environ["GITHUB_RUN_ID"])
assert not evidence.exists()
evidence.mkdir(mode=0o700)
for name in ("source", "derived", "cache", "tmp", "release"):
    (root / name).mkdir(mode=0o700)
export = root / "source"
library = Path.home() / "Library/Application Support/Framelet"
library_identity = None
environment = {key: os.environ[key] for key in ("PATH", "HOME", "LANG") if key in os.environ}
environment.update(DEVELOPER_DIR="/Applications/Xcode_16.4.app/Contents/Developer", CI="true",
    TMPDIR=str(root / "tmp") + "/", CLANG_MODULE_CACHE_PATH=str(root / "cache/modules"),
    SWIFTPM_MODULECACHE_OVERRIDE=str(root / "cache/swiftpm"), GIT_OPTIONAL_LOCKS="0")
app = root / "release/Framelet.app"
debug_app = root / "derived/Build/Products/Debug/Framelet.app"
runner = root / "derived/Build/Products/Debug/FrameletAcceptance-Runner.app"
result = evidence / "ui.xcresult"
report = {"schemaVersion": 1, "kind": "framelet-release-captured-playback", "caseId": "FUI04", "source": source,
    "status": "failed", "commands": [], "errors": [], "cleanup": {}, "runtimeObservations": [],
    "nativeProfile": {"architecture": platform.machine(), "macOS": platform.mac_ver()[0],
        "runnerLabel": "macos-15-intel", "appBuild": "Exact 0.1.4 universal Release payload; Debug UI harness only"},
    "oldCasesReplayed": False, "captureOrExportRequested": False, "devicePermissionActions": False, "nonce": nonce}
started = time.monotonic()
cleanup_phase = False
ui_invoked = False
retained_native_children = []
baseline = None
fixture_before = None
bundle_before = None
sha = lambda data: hashlib.sha256(data).hexdigest()
SPARSE_CACHE_LIMITS = {
    "derived/CompilationCache.noindex/generic/v1.1/v8.data": 16 * 1024 ** 3,
    "derived/CompilationCache.noindex/generic/v1.1/v8.index": 8 * 1024 ** 3,
    "derived/CompilationCache.noindex/generic/v1.1/v3.actions": 1024 ** 3,
}
report["storagePolicy"] = {"allocatedBytesMaximum": 4 * 1024 ** 3,
    "otherApparentBytesMaximum": 4 * 1024 ** 3, "namespaceApparentBytesMaximum": 29 * 1024 ** 3,
    "entriesMaximum": 32768, "onlyMeasuredSparseCachePaths": SPARSE_CACHE_LIMITS,
    "evidence": "docs/results/2026/11-12/release-playback-attempt-2.json",
    "localStorageGuardException": False}


def sample_runtime():
    observation = subprocess.run(["/bin/ps", "-axww", "-o", "pid=,command="], capture_output=True, timeout=3)
    assert observation.returncode == 0 and len(observation.stdout) <= 2 * 1024 ** 2
    own = []
    for line in observation.stdout.decode().splitlines():
        pair = line.strip().split(None, 1)
        if len(pair) == 2:
            for binary in (app / "Contents/MacOS/Framelet", debug_app / "Contents/MacOS/Framelet"):
                if pair[1] == str(binary) or pair[1].startswith(str(binary) + " "):
                    assert len(pair[1]) <= 4096
                    own.append({"pid": int(pair[0]), "executable": str(binary), "command": pair[1]})
    assert len(report["runtimeObservations"]) < 900
    report["runtimeObservations"].append({"monotonic": time.monotonic(), "applications": own})


def unpack(item, maximum):
    assert len(item["gzipBase64"]) <= 16 * 1024 ** 2
    with gzip.GzipFile(fileobj=io.BytesIO(base64.b64decode(item["gzipBase64"], validate=True))) as stream:
        data = stream.read(maximum + 1)
    assert 0 < len(data) == item["bytes"] <= maximum and sha(data) == item["sha256"]
    return data


def bundle_snapshot():
    assert app.is_dir() and not app.is_symlink()
    rows = {}
    for path in [app, *sorted(app.rglob("*"))]:
        assert not path.is_symlink()
        row = {"type": "file" if path.is_file() else "directory", "mode": stat.S_IMODE(path.stat().st_mode)}
        if path.is_file():
            assert path.stat().st_size <= 8 * 1024 ** 2
            data = path.read_bytes()
            row.update(bytes=len(data), sha256=sha(data))
        else:
            assert path.is_dir()
        rows[str(path.relative_to(app))] = row
    return rows


def fixture_snapshot():
    current = library.lstat()
    assert stat.S_ISDIR(current.st_mode) and not library.is_symlink()
    assert (current.st_dev, current.st_ino) == (library_identity.st_dev, library_identity.st_ino)
    assert (library / ".acceptance-owner").read_text() == nonce
    rows = {}
    for path in sorted(library.rglob("*")):
        assert not path.is_symlink()
        if path.is_file():
            assert path.stat().st_size <= 1024 * 1024
            rows[str(path.relative_to(library))] = {"bytes": path.stat().st_size, "sha256": sha(path.read_bytes())}
    assert len(rows) == 4 and sum(row["bytes"] for row in rows.values()) < 65536
    return rows


def sample_storage(enforce):
    paths = list(root.rglob("*"))
    rows = []
    nonregular_cache = []
    for path in paths:
        try: value = path.lstat()
        except FileNotFoundError: continue  # A compiler may atomically replace a temporary.
        if str(path.relative_to(root)) in SPARSE_CACHE_LIMITS and not stat.S_ISREG(value.st_mode):
            nonregular_cache.append({"path": str(path.relative_to(root)), "mode": value.st_mode})
        if stat.S_ISREG(value.st_mode):
            rows.append({"path": str(path.relative_to(root)), "logicalBytes": value.st_size,
                "allocatedBytes": value.st_blocks * 512, "device": value.st_dev,
                "inode": value.st_ino, "links": value.st_nlink,
                "canonicalPath": path.resolve() == path})
    unique = {(row["device"], row["inode"]): row for row in rows}
    sparse = [row for row in rows if row["path"] in SPARSE_CACHE_LIMITS]
    invalid_sparse = [row for row in sparse if row["logicalBytes"] > SPARSE_CACHE_LIMITS[row["path"]]
        or row["links"] != 1 or not row["canonicalPath"]] + nonregular_cache
    snapshot = {"monotonic": time.monotonic(), "entries": len(paths),
        "logicalBytes": sum(row["logicalBytes"] for row in rows),
        "allocatedBytes": sum(row["allocatedBytes"] for row in unique.values()),
        "uniqueLogicalBytes": sum(row["logicalBytes"] for row in unique.values()),
        "uniqueRegularFiles": len(unique),
        "nonCacheLogicalBytes": sum(row["logicalBytes"] for row in rows if row["path"] not in SPARSE_CACHE_LIMITS),
        "measuredSparseCacheFiles": sparse, "invalidSparseCacheFiles": invalid_sparse,
        "largest": sorted(rows, key=lambda row: row["logicalBytes"], reverse=True)[:16]}
    snapshots = report.setdefault("storageSnapshots", [])
    assert len(snapshots) < 256
    snapshots.append(snapshot)
    report["maximumOwnedBytes"] = max(report.get("maximumOwnedBytes", 0), snapshot["logicalBytes"])
    report["maximumOwnedAllocatedBytes"] = max(report.get("maximumOwnedAllocatedBytes", 0), snapshot["allocatedBytes"])
    if enforce and (len(paths) > 32768 or snapshot["logicalBytes"] > 29 * 1024 ** 3
            or snapshot["allocatedBytes"] > 4 * 1024 ** 3 or snapshot["nonCacheLogicalBytes"] > 4 * 1024 ** 3
            or invalid_sparse):
        (evidence / "storage-bound-state.json").write_text(json.dumps(snapshot, indent=2))
        raise RuntimeError("owned storage bound: apparent=" + str(snapshot["logicalBytes"])
            + ", allocated=" + str(snapshot["allocatedBytes"]) + ", entries=" + str(len(paths)))


def group_members(pid, name):
    observed = subprocess.run(["/bin/ps", "-axww", "-o", "pid=,pgid=,uid=,command="], capture_output=True, timeout=5)
    assert observed.returncode == 0 and len(observed.stdout) <= 4 * 1024 ** 2 and len(observed.stderr) <= 65536
    rows = []
    for line in observed.stdout.decode().splitlines():
        parts = line.strip().split(None, 3)
        if len(parts) == 4 and all(value.isdecimal() for value in parts[:3]) and int(parts[1]) == pid:
            assert len(parts[3]) <= 8192
            rows.append({"pid": int(parts[0]), "group": int(parts[1]), "uid": int(parts[2]), "command": parts[3]})
    assert len(rows) <= 64
    observations = report.setdefault("processGroupObservations", [])
    assert len(observations) < 256
    observations.append({"command": name, "group": pid, "members": rows, "monotonic": time.monotonic(),
        "psStdoutBytes": len(observed.stdout), "psStdoutSHA256": sha(observed.stdout)})
    return rows


def run(name, args, seconds=30, cwd=None):
    protects_possible_writer = name == "native-ui"
    deadline = min(started + (990 if cleanup_phase else 900), time.monotonic() + seconds)
    assert time.monotonic() + 1 < deadline
    child = subprocess.Popen(args, cwd=cwd or repo, env=environment, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    selector = selectors.DefaultSelector()
    for label, stream in (("stdout", child.stdout), ("stderr", child.stderr)):
        os.set_blocking(stream.fileno(), False); selector.register(stream, selectors.EVENT_READ, label)
    streams = {key: bytearray() for key in ("stdout", "stderr")}
    observed = {key: [0, hashlib.sha256()] for key in streams}
    eof = set(); signals = []; error = None; inspection_errors = []; absent = False
    storage_sampled = runtime_sampled = 0

    def drain(wait, enforce=True):
        for event, _ in selector.select(wait):
            data = os.read(event.fileobj.fileno(), 65536)
            label = event.data
            if not data:
                eof.add(label); selector.unregister(event.fileobj)
            else:
                observed[label][0] += len(data); observed[label][1].update(data)
                room = 2 * 1024 ** 2 - len(streams[label]); streams[label].extend(data[:room])
                if enforce: assert len(data) <= room, "Command stream bound"

    try:
        while selector.get_map():
            if time.monotonic() - storage_sampled >= 5:
                sample_storage(enforce=not cleanup_phase); storage_sampled = time.monotonic()
            if protects_possible_writer and time.monotonic() - runtime_sampled >= 1:
                sample_runtime(); runtime_sampled = time.monotonic()
            assert time.monotonic() < deadline, "Command deadline"
            drain(0.1)
        child.wait(timeout=5)
    except BaseException as caught:
        error = caught
    finally:
        try:
            if child.poll() is None and error is None:
                try: child.wait(timeout=2)
                except subprocess.TimeoutExpired: pass
            # No native group signal, including on timeout or observation failure.
            # A live compiler/read child requires fresh current-UID group metadata.
            if child.poll() is None and not protects_possible_writer:
                members = group_members(child.pid, name)
                assert members and any(row["pid"] == child.pid for row in members)
                assert all(row["uid"] == os.getuid() for row in members), "Unknown ownership; no signal"
                if child.poll() is None:
                    os.killpg(child.pid, signal.SIGTERM); signals.append("SIGTERM")
                until = time.monotonic() + 3
                while child.poll() is None and time.monotonic() < until:
                    try: drain(0.1, False)
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
                try: drain(0.1, False)
                except BaseException: pass
        except BaseException:
            inspection_errors.append(traceback.format_exc())
        selector.close()
        if child.poll() is None:
            retained_native_children.append(child)
        else:
            child.stdout.close(); child.stderr.close()
        row = {"name": name, "args": args, "exitCode": child.returncode,
            "stopReason": str(error) if error else None, "ownedGroupAbsent": absent,
            "possibleWriterGroupNeverSignalled": protects_possible_writer,
            "nonWriterBuildOrReadGroupSignalled": bool(signals), "signals": signals,
            "ownershipInspectionErrors": inspection_errors, "streams": {}}
        for label, data in streams.items():
            raw = bytes(data)
            (evidence / (name + "." + label + ".txt")).write_bytes(raw)
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
    raw = run("source-" + str(len(report.get("sourceGuards", []))), ["/usr/bin/git", "ls-tree", "-r", "--full-tree", "HEAD"])
    for line in raw.decode().splitlines():
        meta, name = line.split("\t", 1)
        mode, kind, blob = meta.split()
        assert kind == "blob" and mode in ("100644", "100755")
        path = repo / name
        assert path.is_file() and not path.is_symlink()
        assert bool(path.stat().st_mode & 0o111) == (mode == "100755")
        assert path.stat().st_size <= 4 * 1024 ** 2
        data = path.read_bytes()
        assert hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest() == blob
        rows.append({"path": name, "mode": mode, "blob": blob, "sha256": sha(data)})
    report.setdefault("sourceGuards", []).append(rows)
    return rows


try:
    assert run("head", ["/usr/bin/git", "rev-parse", "HEAD"]).decode().strip() == source
    assert not run("status", ["/usr/bin/git", "status", "--porcelain", "--untracked-files=all", "--ignored"]).strip()
    run("toolchain", ["/usr/bin/xcodebuild", "-version"])
    baseline = source_guard()
    index_before = sha((repo / ".git/index").read_bytes())
    native_case = (repo / "Tests/e2e/FrameletReleasePlaybackAcceptance.swift").read_bytes()
    assert sha(native_case[:15300]) == "941ed334c6987cdc2991070bcfbda568f15da9abedffcf71fd8cf0e3065c6f1d"
    report["fullNativeCaseOriginalPrefixSHA256"] = sha(native_case[:15300])
    report["nativeCaseChanges"] = "None; omit optional rendering-probe configuration so closed diagnostics never launch"
    raw = (repo / "docs/results/2026/11-12/compatible-preview-attempt-1.json").read_bytes()
    assert sha(raw) == PACKAGE_RECEIPT_SHA256
    package = json.loads(raw)
    assert package["status"] == "passed" and package["cleanup"]["verified"] and package["cleanup"]["rootAbsent"]
    assert package["sourceCommit"] == "460612a0787d081eb60bbc83fa7cc02c05387ddd"
    assert package["nativeAcceptance"]["caseId"] == "FUI03" and not package["ownedSignals"]
    by_path = {row["path"]: row for row in baseline}
    for name, row in package["sourceVector"].items():
        if name in ("Package.swift", "Tests/ci/ReleasePlaybackPixels.swift") or name.startswith(("Sources/", "Resources/", "script/",
                "Tests/FrameletCoreTests/", "Tests/FrameletPlaybackTests/", "Tests/FrameletAcceptance.xcodeproj/", "Tests/e2e/")):
            assert by_path[name]["sha256"] == row["sha256"]
    report["releasedSourceAndRuntimeInputs"] = {"source": package["sourceCommit"],
        "receiptSHA256": sha(raw), "allPackageRuntimeResourceScriptInputsMatch": True}
    originals = package["retainedOriginals"]
    archive = root / "released.zip"
    archive.write_bytes(unpack(originals["Framelet-0.1.4-macos-universal.zip"], 8 * 1024 ** 2))
    manifest = json.loads(unpack(originals["Framelet-preview-manifest.json"], 65536))
    assert manifest["sourceCommit"] == package["sourceCommit"] and manifest["version"] == "0.1.4" and manifest["build"] == "5"
    assert manifest["softwareCompositorQualification"]["caseCount"] == 6
    assert manifest["softwareCompositorQualification"]["frameCount"] == 8
    assert manifest["archive"]["sha256"] == sha(archive.read_bytes())
    with zipfile.ZipFile(archive) as zipped:
        entries = zipped.infolist()
        assert len(entries) <= 512 and len({p.filename for p in entries}) == len(entries)
        assert sum(p.file_size for p in entries) <= 32 * 1024 ** 2
        for entry in entries:
            path = PurePosixPath(entry.filename)
            assert not path.is_absolute() and ".." not in path.parts and "\\" not in entry.filename
            assert path.parts[0] in ("Framelet.app", "__MACOSX")
            assert not stat.S_ISLNK(entry.external_attr >> 16) and not entry.flag_bits & 1
    run("extract-released-input", ["/usr/bin/ditto", "-x", "-k", str(archive), str(root / "release")])
    assert {p.name for p in (root / "release").iterdir()} == {"Framelet.app"}
    bundle_before = bundle_snapshot()
    expected_bundle = {name: {key: value for key, value in row.items() if key != "xattrs"}
        for name, row in manifest["bundleManifest"].items()}
    assert bundle_before == expected_bundle
    run("released-signature", ["/usr/bin/codesign", "--verify", "--strict", "--all-architectures", str(app)])
    entitlements = run("released-entitlements", ["/usr/bin/codesign", "-d", "--entitlements", ":-", str(app)])
    assert not entitlements.strip() or plistlib.loads(entitlements) == {}
    report["releasedBundleBefore"] = bundle_before
    report["releasedArchive"] = {"bytes": archive.stat().st_size, "sha256": sha(archive.read_bytes()),
        "productionEntitlementsEmpty": True, "resignedOrModified": False}

    # Exact three already-authored inputs; no earlier audit tree is copied.
    seed = repo / "docs/results/2026/11-12/capture-attempt-4-files/library/Recordings/4A689114-5E06-43A3-AE28-BD9B9FDB524E.framelet"
    pins = {"manifest.json": "618cc4de511ee689fa5725a789af4e2bc9601ba65a50eb0d6cd4974cf642e80c",
        "segments/C456C486-F99C-498F-9ACE-7BBB746813A9-screen.mp4": "a255cd9c0d2fd723c28d1b48794ff47cf2b5b4d3a57de2eb7fd18c08b723f329",
        "segments/112458AE-5A21-4B59-A225-6466A4AE91D3-screen.mp4": "eae605da7fa85a55ab5c5a5be0dc2eb1e67e04f15b556173079b47e0d9767c91"}
    assert library.parent.is_dir() and library.parent.resolve() == library.parent and not library.exists() and not library.is_symlink()
    library.mkdir(mode=0o700); library_identity = library.stat()
    (library / ".acceptance-owner").write_text(nonce)
    target_package = library / "Recordings" / seed.name
    for name, digest in pins.items():
        path = seed / name
        assert path.is_file() and not path.is_symlink() and path.stat().st_size < 65536
        data = path.read_bytes(); assert sha(data) == digest
        target = target_package / name; target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream: stream.write(data)
    project = json.loads((target_package / "manifest.json").read_bytes())
    assert project["status"] == "ready" and len(project["segments"]) == len(project["clips"]) == 2
    assert not any(project["options"][key] for key in ("cameraEnabled", "capturesMicrophone", "capturesSystemAudio"))
    fixture_before = fixture_snapshot()
    report["fixtureHashesBefore"] = fixture_before

    for row in baseline:
        name = row["path"]
        if name != "Package.swift" and not name.startswith(("Sources/", "Resources/", "Tests/e2e/", "Tests/FrameletAcceptance.xcodeproj/", "Tests/FrameletCoreTests/", "Tests/FrameletPlaybackTests/")):
            continue
        target = export / name; target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((repo / name).read_bytes()); target.chmod(0o755 if row["mode"] == "100755" else 0o644)
    config = {"root": str(root), "nonce": nonce, "title": project["title"],
        "firstDuration": str(project["segments"][0]["durationSeconds"]),
        "totalDuration": str(sum(row["durationSeconds"] for row in project["segments"]))}
    (export / "Tests/e2e/FixtureConfig.json").write_text(json.dumps(config))
    pixel_verifier = root / "release-playback-pixels"
    run("pixel-verifier-compile", ["/usr/bin/xcrun", "swiftc", "-parse-as-library", "-swift-version", "5",
        "-module-cache-path", str(root / "cache/pixel-modules"), str(repo / "Tests/ci/ReleasePlaybackPixels.swift"),
        "-o", str(pixel_verifier)], seconds=120)
    common = ["/usr/bin/xcodebuild", "-project", "Tests/FrameletAcceptance.xcodeproj", "-scheme", "FrameletAcceptance",
        "-configuration", "Debug", "-destination", "platform=macOS,arch=x86_64", "-derivedDataPath", str(root / "derived")]
    run("build-ui-harness-and-unused-debug-dependency", common + ["build-for-testing"], seconds=300, cwd=export)
    files = list((root / "derived/Build/Products").glob("*.xctestrun"))
    assert len(files) == 1
    original_run = files[0]
    original = plistlib.loads(original_run.read_bytes())
    bound = copy.deepcopy(original)
    edits = []
    def resolve(value):
        return Path(value.replace("__TESTROOT__", str(original_run.parent))).resolve()
    def bind(value, trail=()):
        if isinstance(value, dict):
            for key, item in value.items():
                if key == "UITargetAppPath":
                    assert isinstance(item, str) and resolve(item) == debug_app.resolve()
                    edits.append({"field": list(trail + (key,)), "from": item, "to": str(app)})
                    value[key] = str(app)
                elif key == "DependentProductPaths":
                    assert isinstance(item, list)
                    for i, path in enumerate(item):
                        if isinstance(path, str) and resolve(path) == debug_app.resolve():
                            edits.append({"field": list(trail + (key, str(i))), "from": path, "to": str(app)})
                            item[i] = str(app)
                else: bind(item, trail + (str(key),))
        elif isinstance(value, list):
            for i, item in enumerate(value): bind(item, trail + (str(i),))
    bind(bound)
    assert sum(row["field"][-1] == "UITargetAppPath" for row in edits) == 1
    assert 1 <= len(edits) <= 2
    run_file = original_run.parent / "ReleasedPlayback.xctestrun"
    run_file.write_bytes(plistlib.dumps(bound))
    (evidence / "original.xctestrun.plist").write_bytes(original_run.read_bytes())
    (evidence / "released.xctestrun.plist").write_bytes(run_file.read_bytes())
    assert bundle_snapshot() == bundle_before
    report["nativeTargetBinding"] = {"app": str(app), "debugDependencyAppNeverAccepted": str(debug_app),
        "originalRunSHA256": sha(original_run.read_bytes()), "boundRunSHA256": sha(run_file.read_bytes()),
        "declaredPathEditsOnly": edits, "bundleIdentifier": "com.alvarovillalbaa.Framelet"}
    ui_invoked = True
    run("native-ui", ["/usr/bin/xcodebuild", "test-without-building", "-xctestrun", str(run_file),
        "-destination", "platform=macOS,arch=x86_64", "-resultBundlePath", str(result),
        "-only-testing:FrameletAcceptance/FrameletReleasePlaybackAcceptance/testFUI04PlayRealCapturedTakesInReleasedApp",
        "-parallel-testing-enabled", "NO", "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "360",
        "-maximum-test-execution-time-allowance", "420"], seconds=600, cwd=export)
    report["nativeTestCommandPassed"] = True
except BaseException:
    report["errors"].append(traceback.format_exc())
finally:
    cleanup_phase = True
    entries = []
    if result.exists():
        try:
            report["testSummary"] = json.loads(run("summary", ["/usr/bin/xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result)]))
            identities = json.loads(run("identities", ["/usr/bin/xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(result)]))
            pending = list(identities.get("testNodes", [])); cases = []
            while pending:
                node = pending.pop()
                if node.get("nodeType") == "Test Case": cases.append(node)
                pending.extend(node.get("children", []))
            report["nativeCases"] = cases
            run("attachments", ["/usr/bin/xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                "--output-path", str(evidence / "attachments")], seconds=60)
            attachment_manifest = json.loads((evidence / "attachments/manifest.json").read_text())
            total = 0
            for case in attachment_manifest:
                assert case["testIdentifier"] == "FrameletReleasePlaybackAcceptance/testFUI04PlayRealCapturedTakesInReleasedApp()"
                for item in case["attachments"]:
                    name = item["exportedFileName"]
                    assert Path(name).name == name and name not in (".", "..")
                    path = evidence / "attachments" / name
                    assert path.is_file() and not path.is_symlink() and path.stat().st_size <= 128 * 1024 ** 2
                    digest = hashlib.sha256()
                    with path.open("rb") as stream:
                        for chunk in iter(lambda: stream.read(65536), b""): digest.update(chunk)
                    human = item["suggestedHumanReadableName"]
                    match = re.fullmatch(r"((?:0[1-9]|10)-[a-z0-9-]+|diagnostic-[a-z0-9-]+|playback-observations|playback-progress|playback-shutdown)_[0-9]+_([A-F0-9-]{36})\.(png|json|accessibility)", human)
                    entry = {"file": name, "name": human, "canonicalName": match[1] + "." + match[3] if match else None,
                        "bytes": path.stat().st_size, "sha256": digest.hexdigest(), "retainedInArtifact": True}
                    entries.append(entry)
                    if match or human.startswith(("App UI hierarchy", "UI Snapshot", "Complete Issue Description")):
                        raw = path.read_bytes(); total += len(raw)
                        assert len(raw) <= 2 * 1024 ** 2 and total <= 16 * 1024 ** 2 and sha(raw) == entry["sha256"]
                        entry["gzipBase64"] = base64.b64encode(gzip.compress(raw, mtime=0)).decode()
            report["attachments"] = entries
            if report.get("nativeTestCommandPassed"):
                summary = report["testSummary"]
                assert summary["totalTestCount"] == summary["passedTests"] == 1
                assert summary["failedTests"] == summary["skippedTests"] == summary["expectedFailures"] == 0
                assert summary["result"] == "Passed" and not summary.get("testFailures")
                assert len(cases) == 1 and cases[0]["name"] == "testFUI04PlayRealCapturedTakesInReleasedApp()" and cases[0]["result"] == "Passed"
                observations = [entry for entry in entries if entry["canonicalName"] == "playback-observations.json"]
                assert len(observations) == 1
                observed = json.loads(gzip.decompress(base64.b64decode(observations[0]["gzipBase64"])))
                assert observed["caseId"] == "FUI04" and observed["status"] == "passed"
                assert all(observed[key] is True for key in ("pauseFreezesPosition", "continuousBoundaryWithoutSeek",
                    "selectedClipChangesStopAndReload", "endedThenReplayFromBeginning", "normalQuitAtEnd"))
                assert observed["captureOrExportRequested"] is False
                runtime = [row for sample in report["runtimeObservations"] for row in sample["applications"]]
                assert runtime and all(row["executable"] == str(app / "Contents/MacOS/Framelet") for row in runtime)
                assert all(any(row["pid"] == phase["processID"] for row in runtime) for phase in observed["phases"])
                report["actualReleasedProcessVerified"] = True
                observation_path = root / "playback-observations.json"
                observation_path.write_text(json.dumps(observed))
                report["uiObservations"] = observed
                image_entries = {entry["canonicalName"][:-4]: entry for entry in entries
                    if entry["canonicalName"] and entry["canonicalName"].endswith(".png")}
                images = {phase["name"]: {"path": str(evidence / "attachments" / image_entries[phase["name"]]["file"]),
                    "sha256": image_entries[phase["name"]]["sha256"]} for phase in observed["phases"]}
                pixel_config = root / "pixel-config.json"
                pixel_config.write_text(json.dumps({"observations": str(observation_path), "images": images}))
                report["pixelVerification"] = json.loads(run("pixel-verification", [str(pixel_verifier), str(pixel_config)], seconds=60))
                assert report["pixelVerification"]["verified"] is True
        except BaseException: report["errors"].append(traceback.format_exc())
    safe = not ui_invoked
    try:
        if baseline is not None:
            assert source_guard() == baseline
            assert sha((repo / ".git/index").read_bytes()) == index_before
            report["cleanup"]["sourceAndIndexUnchanged"] = True
        if bundle_before is not None:
            report["releasedBundleAfter"] = bundle_snapshot()
            assert report["releasedBundleAfter"] == bundle_before
            report["cleanup"]["releasedBundleUnchanged"] = True
        if fixture_before is not None:
            report["fixtureHashesAfter"] = fixture_snapshot()
            assert report["fixtureHashesAfter"] == fixture_before
            report["fixtureReadOnlyUnchanged"] = True
        shutdown = [entry for entry in entries if entry["canonicalName"] == "playback-shutdown.json"]
        if ui_invoked:
            assert len(shutdown) == 1, "No native acknowledgment; retain app/library/root"
            acknowledgment = json.loads(gzip.decompress(base64.b64decode(shutdown[0]["gzipBase64"])))
            report["shutdownAcknowledgment"] = acknowledgment
            safe = acknowledgment["caseId"] == "FUI04" and acknowledgment["safeToTerminate"] is True
            safe = safe and acknowledgment["captureOrExportRequested"] is False and acknowledgment["forcedWriterTermination"] is False
        report["cleanup"]["noCaptureAcknowledged"] = safe
    except BaseException:
        safe = False
        report["errors"].append(traceback.format_exc())
    try:
        # Preserve only the four bounded authored fixture inputs on any failure.
        retained = []
        if library_identity is not None:
            fixture_snapshot()
            folder = evidence / "authored-inputs"; folder.mkdir(mode=0o700)
            for path in sorted(library.rglob("*")):
                if path.is_file():
                    raw = path.read_bytes()
                    relative = str(path.relative_to(library))
                    target = folder / relative; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(raw)
                    retained.append({"path": relative, "bytes": len(raw), "sha256": sha(raw),
                        "gzipBase64": base64.b64encode(gzip.compress(raw, mtime=0)).decode()})
        report["retainedAuthoredInputs"] = retained
        report["cleanup"]["authoredInputsRetained"] = True
    except BaseException:
        safe = False
        report["errors"].append(traceback.format_exc())
    try:
        assert safe, "Unacknowledged native state/preservation: no app signals or library/root removal"
        assert time.monotonic() - started < 990, "Cleanup deadline: retain owned paths"
        def owned_processes():
            observation = subprocess.run(["/bin/ps", "-axww", "-o", "pid=,uid=,command="], capture_output=True, timeout=10)
            assert observation.returncode == 0 and len(observation.stdout) <= 4 * 1024 ** 2
            rows = []
            for line in observation.stdout.decode().splitlines():
                pair = line.strip().split(None, 2)
                if len(pair) == 3 and int(pair[0]) != os.getpid() and str(root) + "/" in pair[2]:
                    assert int(pair[1]) == os.getuid(), "Unexpected UID; retain paths without signals"
                    rows.append({"pid": int(pair[0]), "uid": int(pair[1]), "command": pair[2]})
            return rows
        owned = owned_processes(); report["cleanup"]["ownedProcessesBefore"] = owned
        for row in owned:
            check = subprocess.run(["/bin/ps", "-ww", "-p", str(row["pid"]), "-o", "uid=,command="], capture_output=True, timeout=5)
            current = check.stdout.decode().strip().split(None, 1)
            if check.returncode == 0 and current == [str(row["uid"]), row["command"]]:
                try: os.kill(row["pid"], signal.SIGTERM)
                except ProcessLookupError: pass
        until = min(started + 990, time.monotonic() + 5)
        remaining = owned_processes()
        while remaining and time.monotonic() < until:
            time.sleep(0.2); remaining = owned_processes()
        report["cleanup"]["ownedProcessesAfter"] = remaining
        assert not remaining
        report["cleanup"]["ownedAppAndRunnerAbsent"] = True
        if library_identity is not None:
            fixture_snapshot()
            shutil.rmtree(library); assert not library.exists()
            report["cleanup"]["ownedLibraryAbsent"] = True
        current = root.lstat()
        assert root.parent == parent and not root.is_symlink()
        assert (current.st_dev, current.st_ino) == (root_identity.st_dev, root_identity.st_ino)
        assert (root / "owner").read_text() == nonce
        shutil.rmtree(root); assert not root.exists()
        report["cleanup"]["ownedRootAbsent"] = True
    except BaseException: report["errors"].append(traceback.format_exc())
    report["elapsedSeconds"] = time.monotonic() - started
    if report.get("nativeTestCommandPassed") and report.get("actualReleasedProcessVerified") and report.get("fixtureReadOnlyUnchanged") and report.get("pixelVerification", {}).get("verified") and not report["errors"]:
        report["status"] = "passed"
        try:
            assert result.parent == evidence and result.is_dir() and not result.is_symlink()
            assert not any(path.is_symlink() for path in result.rglob("*"))
            shutil.rmtree(result); assert not result.exists()
            report["cleanup"]["passingRawResultIntermediateRemoved"] = True
        except BaseException:
            report["status"] = "failed"; report["errors"].append(traceback.format_exc())
    data = json.dumps(report, separators=(",", ":")).encode()
    assert len(data) <= 48 * 1024 ** 2
    (evidence / "receipt.json").write_bytes(data)
    print("FRAMELET_COMPATIBLE_PLAYBACK_RESULT=" + base64.b64encode(gzip.compress(data, mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
