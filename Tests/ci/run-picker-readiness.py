"""FUI03A: authored fixture and native picker presentation/cancellation only."""
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
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

source = os.environ["FRAMELET_SOURCE_COMMIT"]
assert re.fullmatch(r"[0-9a-f]{40}", source)
assert platform.system() == "Darwin" and platform.machine() == "arm64"
assert os.environ["GITHUB_REPOSITORY"] == "alvarovillalbaa/framelet"
assert os.environ["GITHUB_REF"] == "refs/heads/qa/framelet-picker-20261112-1"
repo = Path.cwd().resolve()
parent = Path(os.environ["RUNNER_TEMP"]).resolve()
root = Path(tempfile.mkdtemp(prefix="framelet-picker-", dir=parent)).resolve()
root_identity = root.stat()
nonce = uuid.uuid4().hex
(root / "owner").write_text(nonce)
evidence = parent / ("framelet-picker-evidence-" + os.environ["GITHUB_RUN_ID"])
assert not evidence.exists()
evidence.mkdir(mode=0o700)
for name in ("source", "derived", "cache", "tmp"):
    (root / name).mkdir(mode=0o700)
export = root / "source"
# Preserve the real user home. The fresh CI account's app-specific library is
# admitted only when absent; no HOME override or production test hook is used.
library = Path.home() / "Library/Application Support/Framelet"
library_identity = None
environment = {key: os.environ[key] for key in ("PATH", "HOME", "LANG") if key in os.environ}
environment.update(DEVELOPER_DIR="/Applications/Xcode_16.4.app/Contents/Developer", CI="true",
    TMPDIR=str(root / "tmp") + "/", CLANG_MODULE_CACHE_PATH=str(root / "cache/modules"),
    SWIFTPM_MODULECACHE_OVERRIDE=str(root / "cache/swiftpm"))
app = root / "derived/Build/Products/Debug/Framelet.app"
runner = root / "derived/Build/Products/Debug/FrameletAcceptance-Runner.app"
fixture = root / "FrameletAuthoredFixture.app"
result = evidence / "ui.xcresult"
report = {"schemaVersion": 1, "kind": "framelet-picker-readiness", "caseId": "FUI03A", "source": source,
          "status": "failed", "commands": [], "errors": [], "cleanup": {}, "oldCasesReplayed": False,
          "captureCameraMicrophoneUsed": False, "simulatorUsed": False, "nonce": nonce}
started = time.monotonic()
cleanup_phase = False
sha = lambda data: hashlib.sha256(data).hexdigest()


def run(name, args, seconds=30, cwd=None):
    remaining = 900 - (time.monotonic() - started)
    assert cleanup_phase or remaining > 0
    deadline = time.monotonic() + (seconds if cleanup_phase else min(seconds, remaining))
    child = subprocess.Popen(args, cwd=cwd or repo, env=environment, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    streams = {"stdout": bytearray(), "stderr": bytearray()}
    selector = selectors.DefaultSelector()
    for key in streams:
        pipe = getattr(child, key)
        os.set_blocking(pipe.fileno(), False)
        selector.register(pipe, selectors.EVENT_READ, key)
    stopped = None
    try:
        while selector.get_map():
            if time.monotonic() > deadline or any(len(data) > 2 * 1024 ** 2 for data in streams.values()):
                stopped = "timeout_or_stream_bound"
                try: os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError: pass
                break
            for event, _ in selector.select(0.1):
                data = os.read(event.fd, 65536)
                if data: streams[event.data].extend(data)
                else: selector.unregister(event.fileobj)
        child.wait(timeout=5)
    finally:
        if child.poll() is None:
            try: os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            child.wait(timeout=5)
        selector.close(); child.stdout.close(); child.stderr.close()
    try:
        os.killpg(child.pid, 0)
    except ProcessLookupError:
        group_absent = True
    else:
        os.killpg(child.pid, signal.SIGKILL)
        time.sleep(0.2)
        try: os.killpg(child.pid, 0)
        except ProcessLookupError: group_absent = True
        else: group_absent = False
    row = {"name": name, "args": args, "exitCode": child.returncode, "stopReason": stopped,
           "ownedGroupAbsent": group_absent, "streams": {}}
    for key, data in streams.items():
        raw = bytes(data)
        (evidence / (name + "." + key + ".txt")).write_bytes(raw)
        row["streams"][key] = {"bytes": len(raw), "sha256": sha(raw), "complete": stopped is None,
            "gzipBase64": base64.b64encode(gzip.compress(raw, mtime=0)).decode()}
    report["commands"].append(row)
    assert child.returncode == 0 and stopped is None and group_absent, name + " failed"
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
        rows.append({"path": name, "mode": mode, "blob": blob, "sha256": sha(path.read_bytes())})
    report.setdefault("sourceGuards", []).append(rows)
    return rows


try:
    assert run("head", ["/usr/bin/git", "rev-parse", "HEAD"]).decode().strip() == source
    assert not run("status", ["/usr/bin/git", "status", "--porcelain"]).strip()
    run("toolchain", ["/usr/bin/xcodebuild", "-version"])
    baseline = source_guard()
    changes = run("qualified-input-diff", ["/usr/bin/git", "diff", "--name-only", "fe0bdaf22417bc3751290c3e56cd0dddf62f3e7d",
        "HEAD", "--", "Package.swift", "Sources", "Resources", "script", "Tests/FrameletCoreTests",
        "Tests/FrameletPlaybackTests", "Tests/e2e/FrameletAcceptance.swift", "Tests/ci/MediaFixture.swift"])
    assert not changes.strip()
    report["qualifiedRuntimeInputsUnchanged"] = True
    for row in baseline:
        name = row["path"]
        if name not in ("Package.swift", "Tests/ci/MediaFixture.swift", "Tests/ci/WindowDisplay.swift", "Tests/ci/PickerFixture.swift") and not name.startswith(("Sources/", "Resources/", "Tests/e2e/", "Tests/FrameletAcceptance.xcodeproj/", "Tests/FrameletCoreTests/", "Tests/FrameletPlaybackTests/")):
            continue
        target = export / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((repo / name).read_bytes()); target.chmod(0o755 if row["mode"] == "100755" else 0o644)
    assert library.parent.is_dir() and library.parent.resolve() == library.parent and not library.exists() and not library.is_symlink()
    library.mkdir(mode=0o700)
    library_identity = library.stat()
    (library / ".acceptance-owner").write_text(nonce)
    config = {"root": str(root), "nonce": nonce}
    (export / "Tests/e2e/FixtureConfig.json").write_text(json.dumps(config))
    (fixture / "Contents/MacOS").mkdir(parents=True)
    info = {"CFBundleIdentifier": "com.alvarovillalbaa.FrameletAuthoredFixture",
        "CFBundleExecutable": "FrameletAuthoredFixture", "CFBundleName": "Framelet Authored Fixture",
        "CFBundlePackageType": "APPL", "LSMinimumSystemVersion": "15.0", "NSPrincipalClass": "NSApplication"}
    (fixture / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
    run("fixture-compile", ["/usr/bin/xcrun", "swiftc", "-parse-as-library", "-swift-version", "5",
        "-module-cache-path", str(root / "cache/fixture-modules"), str(export / "Tests/ci/PickerFixture.swift"),
        "-o", str(fixture / "Contents/MacOS/FrameletAuthoredFixture")], seconds=120)
    run("fixture-sign", ["/usr/bin/codesign", "--force", "--sign", "-", str(fixture)])
    run("fixture-signature", ["/usr/bin/codesign", "--verify", "--strict", str(fixture)])
    entitlements = run("fixture-entitlements", ["/usr/bin/codesign", "-d", "--entitlements", ":-", str(fixture)])
    assert not entitlements.strip() or plistlib.loads(entitlements) == {}
    fixture_identity = fixture.stat()
    def fixture_snapshot():
        assert not any(p.is_symlink() for p in fixture.rglob("*"))
        return {str(p.relative_to(fixture)): sha(p.read_bytes()) for p in sorted(fixture.rglob("*")) if p.is_file()}
    report["fixtureHashesBefore"] = fixture_snapshot()
    report["fixtureBinding"] = {"bundleIdentifier": info["CFBundleIdentifier"], "path": str(fixture),
        "title": "Framelet authored capture " + nonce, "device": fixture_identity.st_dev, "inode": fixture_identity.st_ino,
        "entitlementsEmpty": True}
    common = ["/usr/bin/xcodebuild", "-project", "Tests/FrameletAcceptance.xcodeproj", "-scheme", "FrameletAcceptance",
        "-configuration", "Debug", "-destination", "platform=macOS,arch=arm64", "-derivedDataPath", str(root / "derived")]
    run("build-for-testing", common + ["build-for-testing"], seconds=300, cwd=export)
    files = list((root / "derived/Build/Products").glob("*.xctestrun"))
    assert len(files) == 1
    run_file = files[0]
    data = run_file.read_bytes()
    (evidence / "native.xctestrun.plist").write_bytes(data)
    pending = [plistlib.loads(data)]; paths = []
    while pending:
        value = pending.pop()
        if isinstance(value, dict):
            if "UITargetAppPath" in value: paths.append(value["UITargetAppPath"])
            pending.extend(value.values())
        elif isinstance(value, list): pending.extend(value)
    assert len(paths) == 1 and Path(paths[0].replace("__TESTROOT__", str(run_file.parent))).resolve() == app.resolve()
    assert plistlib.loads((app / "Contents/Info.plist").read_bytes())["CFBundleIdentifier"] == "com.alvarovillalbaa.Framelet"
    run("production-signature", ["/usr/bin/codesign", "--force", "--sign", "-", str(app)])
    entitlements = run("app-entitlements", ["/usr/bin/codesign", "-d", "--entitlements", ":-", str(app)])
    assert not entitlements.strip() or plistlib.loads(entitlements) == {}
    run("signature", ["/usr/bin/codesign", "--verify", "--strict", str(app)])
    report["nativeTargetBinding"] = {"app": str(app), "bundleIdentifier": "com.alvarovillalbaa.Framelet", "runFileSHA256": sha(data), "productionEntitlementsEmpty": True}
    run("launch-fixture", ["/usr/bin/open", "-n", "-a", str(fixture), "--args", nonce])
    run("native-ui", ["/usr/bin/xcodebuild", "test-without-building", "-xctestrun", str(run_file),
        "-destination", "platform=macOS,arch=arm64", "-resultBundlePath", str(result),
        "-only-testing:FrameletAcceptance/FrameletPickerReadiness/testFUI03APresentOwnedWindowPicker",
        "-parallel-testing-enabled", "NO", "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "240",
        "-maximum-test-execution-time-allowance", "300"], seconds=480, cwd=export)
    report["nativeTestCommandPassed"] = True
    report["fixtureHashesAfter"] = fixture_snapshot()
    assert report["fixtureHashesAfter"] == report["fixtureHashesBefore"]
    report["fixtureReadOnlyUnchanged"] = True
    assert list(library.iterdir()) == [library / ".acceptance-owner"]
    report["noRecordingCreated"] = True
except BaseException:
    report["errors"].append(traceback.format_exc())
finally:
    cleanup_phase = True
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
            run("attachments", ["/usr/bin/xcrun", "xcresulttool", "export", "attachments", "--path", str(result), "--output-path", str(evidence / "attachments")], seconds=60)
            manifest = json.loads((evidence / "attachments/manifest.json").read_text())
            entries = []; total = 0
            report["attachments"] = entries
            for case in manifest:
                assert case["testIdentifier"] == "FrameletPickerReadiness/testFUI03APresentOwnedWindowPicker()"
                for item in case["attachments"]:
                    name = item["exportedFileName"]
                    assert Path(name).name == name and name not in (".", "..")
                    path = evidence / "attachments" / name
                    assert path.is_file() and not path.is_symlink()
                    assert path.stat().st_size <= 128 * 1024 ** 2
                    digest = hashlib.sha256()
                    with path.open("rb") as stream:
                        for chunk in iter(lambda: stream.read(65536), b""): digest.update(chunk)
                    human = item["suggestedHumanReadableName"]
                    match = re.fullmatch(r"(0[1-4]-[a-z0-9-]+|diagnostic-[a-z0-9-]+|picker-observations)_[0-9]+_([A-F0-9-]{36})\.(png|json|accessibility)", human)
                    entry = {"file": name, "name": human, "canonicalName": match[1] + "." + match[3] if match else None,
                        "bytes": path.stat().st_size, "sha256": digest.hexdigest(), "retainedInArtifact": True}
                    entries.append(entry)
                    if match or human.startswith(("App UI hierarchy", "UI Snapshot", "Complete Issue Description")):
                        raw = path.read_bytes(); total += len(raw)
                        assert len(raw) <= 2 * 1024 ** 2 and total <= 8 * 1024 ** 2
                        assert sha(raw) == entry["sha256"]
                        entry["gzipBase64"] = base64.b64encode(gzip.compress(raw, mtime=0)).decode()
            report["attachments"] = entries
            if report.get("nativeTestCommandPassed"):
                summary = report["testSummary"]
                assert summary["totalTestCount"] == summary["passedTests"] == 1 and summary["failedTests"] == summary["skippedTests"] == 0
                assert summary["result"] == "Passed" and not summary.get("testFailures")
                assert len(cases) == 1 and cases[0]["name"] == "testFUI03APresentOwnedWindowPicker()" and cases[0]["result"] == "Passed"
                for phase in ("01-authored-fixture", "02-recorder-ready", "03-native-picker", "04-picker-cancelled"):
                    assert len([entry for entry in entries if entry["canonicalName"] == phase + ".png"]) == 1
                observations = [entry for entry in entries if entry["canonicalName"] == "picker-observations.json"]
                assert len(observations) == 1
                observed = json.loads(gzip.decompress(base64.b64decode(observations[0]["gzipBase64"])))
                assert observed["caseId"] == "FUI03A" and observed["status"] == "presentation-cancellation-observed"
                assert observed["fixtureTitle"] == report["fixtureBinding"]["title"]
                assert observed["sourceSelected"] is False and observed["startClicked"] is False
                assert observed["capturePerformed"] is False and observed["cameraMicrophoneSystemAudioOff"] is True
                assert observed["readyAfterCancel"] is True
                report["uiObservations"] = observed
        except BaseException: report["errors"].append(traceback.format_exc())
    try:
        raw = run("owned-processes", ["/bin/ps", "-axo", "pid=,command="])
        owned = []
        for line in raw.decode().splitlines():
            pid, command = line.strip().split(None, 1) if " " in line.strip() else ("0", "")
            if any(str(path) + "/" in command for path in (app, runner, fixture)):
                owned.append(int(pid)); os.kill(int(pid), signal.SIGTERM)
        if owned: time.sleep(1)
        raw = run("owned-processes-after", ["/bin/ps", "-axo", "pid=,command="])
        assert not any(str(path) + "/" in raw.decode() for path in (app, runner, fixture))
        report["cleanup"]["ownedAppAndRunnerAbsent"] = True
        assert source_guard() == baseline
        report["cleanup"]["sourceUnchanged"] = True
        if library_identity is not None:
            current = library.lstat()
            assert not library.is_symlink() and stat.S_ISDIR(current.st_mode)
            assert (current.st_dev, current.st_ino) == (library_identity.st_dev, library_identity.st_ino)
            assert (library / ".acceptance-owner").read_text() == nonce
            # Preserve the generated manifest/media before removing this fresh
            # library, including when the UI case stops after a partial edit.
            fixture_files = []
            fixture_bytes = 0
            for path in sorted(library.rglob("*")):
                assert not path.is_symlink()
                if not path.is_file(): continue
                raw = path.read_bytes(); fixture_bytes += len(raw)
                assert len(fixture_files) < 16 and len(raw) <= 4 * 1024 ** 2 and fixture_bytes <= 8 * 1024 ** 2
                fixture_files.append({"path": str(path.relative_to(library)), "bytes": len(raw), "sha256": sha(raw),
                    "gzipBase64": base64.b64encode(gzip.compress(raw, mtime=0)).decode()})
            report["ownedFixtureFiles"] = fixture_files
            (evidence / "owned-fixture-state.json").write_text(json.dumps(fixture_files, indent=2) + "\n")
            output = root / "authored-ui-export.mp4"
            if output.exists():
                raw = output.read_bytes(); assert len(raw) <= 8 * 1024 ** 2
                report["exportedMP4"] = {"bytes": len(raw), "sha256": sha(raw), "gzipBase64": base64.b64encode(gzip.compress(raw, mtime=0)).decode()}
            shutil.rmtree(library)
            assert not library.exists()
            report["cleanup"]["ownedLibraryAbsent"] = True
        current = root.lstat()
        assert root.parent == parent and not root.is_symlink() and (current.st_dev, current.st_ino) == (root_identity.st_dev, root_identity.st_ino)
        shutil.rmtree(root); assert not root.exists()
        report["cleanup"]["ownedRootAbsent"] = True
    except BaseException: report["errors"].append(traceback.format_exc())
    report["elapsedSeconds"] = time.monotonic() - started
    if report.get("nativeTestCommandPassed") and report.get("uiObservations") and report.get("fixtureReadOnlyUnchanged") and report.get("noRecordingCreated") and not report["errors"]:
        report["status"] = "passed"
        # Keep exported originals and structured Apple results. A passing raw
        # bundle duplicates large automatic videos already in attachments.
        # Failed raw bundles remain intact for diagnosis/recovery.
        try:
            assert result.parent == evidence and result.is_dir() and not result.is_symlink()
            assert not any(path.is_symlink() for path in result.rglob("*"))
            shutil.rmtree(result)
            assert not result.exists()
            report["cleanup"]["passingRawResultIntermediateRemoved"] = True
            report["nativeResultRetention"] = "Complete exported attachments, command streams, native summary and identities retained; passing raw xcresult intermediate removed."
        except BaseException:
            report["status"] = "failed"
            report["errors"].append(traceback.format_exc())
    data = json.dumps(report, separators=(",", ":")).encode()
    assert len(data) <= 16 * 1024 ** 2
    (evidence / "receipt.json").write_bytes(data)
    print("FRAMELET_PICKER_READINESS_RESULT=" + base64.b64encode(gzip.compress(data, mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
