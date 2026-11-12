"""FUI03: actual owned-window recording, acknowledged shutdown and file proof."""
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
assert platform.system() == "Darwin" and platform.machine() == "x86_64"
assert os.environ["GITHUB_REPOSITORY"] == "alvarovillalbaa/framelet"
assert os.environ["GITHUB_REF"] == "refs/heads/qa/framelet-capture-20261112-3"
repo = Path.cwd().resolve()
parent = Path(os.environ["RUNNER_TEMP"]).resolve()
root = Path(tempfile.mkdtemp(prefix="framelet-capture-", dir=parent)).resolve()
root_identity = root.stat()
nonce = uuid.uuid4().hex
(root / "owner").write_text(nonce)
evidence = parent / ("framelet-capture-evidence-" + os.environ["GITHUB_RUN_ID"])
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
report = {"schemaVersion": 1, "kind": "framelet-actual-window-capture", "caseId": "FUI03", "source": source,
          "nativeProfile": {"architecture": platform.machine(), "macOS": platform.mac_ver()[0], "runnerLabel": "macos-15-intel"},
          "status": "failed", "commands": [], "errors": [], "cleanup": {}, "oldCasesReplayed": False,
          "cameraMicrophoneSystemAudioPermitted": False, "simulatorUsed": False, "nonce": nonce}
started = time.monotonic()
cleanup_phase = False
ui_invoked = False
observer = None
observer_handles = []
retained_native_children = []
sha = lambda data: hashlib.sha256(data).hexdigest()


def run(name, args, seconds=30, cwd=None):
    protects_possible_writer = name == "native-ui"
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
                if not protects_possible_writer:
                    try: os.killpg(child.pid, signal.SIGKILL)
                    except ProcessLookupError: pass
                break
            for event, _ in selector.select(0.1):
                data = os.read(event.fd, 65536)
                if data: streams[event.data].extend(data)
                else: selector.unregister(event.fileobj)
        if not (protects_possible_writer and stopped):
            try: child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                if not protects_possible_writer: raise
                stopped = "native_process_retained_without_writer_signal"
    finally:
        if child.poll() is None and not protects_possible_writer:
            try: os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            child.wait(timeout=5)
        selector.close()
        if child.poll() is None and protects_possible_writer:
            # Keep pipes/session alive through partial-evidence preservation.
            # No parent/group signal may force an unfinished app writer down.
            retained_native_children.append(child)
        else:
            child.stdout.close(); child.stderr.close()
    try:
        os.killpg(child.pid, 0)
    except ProcessLookupError:
        group_absent = True
    else:
        if protects_possible_writer:
            group_absent = False
        else:
            os.killpg(child.pid, signal.SIGKILL)
            time.sleep(0.2)
            try: os.killpg(child.pid, 0)
            except ProcessLookupError: group_absent = True
            else: group_absent = False
    row = {"name": name, "args": args, "exitCode": child.returncode, "stopReason": stopped,
           "ownedGroupAbsent": group_absent, "possibleWriterGroupNeverSignalled": protects_possible_writer,
           "streams": {}}
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
    changes = run("qualified-input-diff", ["/usr/bin/git", "diff", "--name-only", "02b244e570c42c5f40e1687e499d5944276e6761",
        "HEAD", "--", "Package.swift", "Sources", "Resources", "script", "Tests/FrameletCoreTests",
        "Tests/FrameletPlaybackTests", "Tests/e2e/FrameletAcceptance.swift", "Tests/e2e/FrameletWindowAcceptance.swift", "Tests/e2e/FrameletPickerReadiness.swift",
        "Tests/ci/MediaFixture.swift"])
    assert not changes.strip()
    report["runtimeInputsUnchangedFromCompiledAttempt2"] = True
    for row in baseline:
        name = row["path"]
        if name not in ("Package.swift", "Tests/ci/MediaFixture.swift", "Tests/ci/WindowDisplay.swift", "Tests/ci/PickerFixture.swift", "Tests/ci/CapturedWindowFiles.swift") and not name.startswith(("Sources/", "Resources/", "Tests/e2e/", "Tests/FrameletAcceptance.xcodeproj/", "Tests/FrameletCoreTests/", "Tests/FrameletPlaybackTests/")):
            continue
        target = export / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((repo / name).read_bytes()); target.chmod(0o755 if row["mode"] == "100755" else 0o644)
    assert library.parent.is_dir() and library.parent.resolve() == library.parent and not library.exists() and not library.is_symlink()
    library.mkdir(mode=0o700)
    library_identity = library.stat()
    (library / ".acceptance-owner").write_text(nonce)
    config = {"root": str(root), "nonce": nonce, "library": str(library)}
    (root / "capture-config.json").write_text(json.dumps(config))
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
        current = fixture.lstat()
        assert stat.S_ISDIR(current.st_mode) and (current.st_dev, current.st_ino) == (fixture_identity.st_dev, fixture_identity.st_ino)
        assert not any(p.is_symlink() for p in fixture.rglob("*"))
        return {str(p.relative_to(fixture)): sha(p.read_bytes()) for p in sorted(fixture.rglob("*")) if p.is_file()}
    report["fixtureHashesBefore"] = fixture_snapshot()
    report["fixtureBinding"] = {"bundleIdentifier": info["CFBundleIdentifier"], "path": str(fixture),
        "title": "Framelet authored capture " + nonce, "device": fixture_identity.st_dev, "inode": fixture_identity.st_ino,
        "entitlementsEmpty": True}
    verifier = root / "capture-file-verifier"
    core_files = sorted(str(p) for p in (export / "Sources/FrameletCore").glob("*.swift"))
    run("verifier-compile", ["/usr/bin/xcrun", "swiftc", "-parse-as-library", "-swift-version", "5",
        "-module-cache-path", str(root / "cache/verifier-modules"), *core_files,
        str(export / "Tests/ci/CapturedWindowFiles.swift"), "-o", str(verifier)], seconds=120)
    common = ["/usr/bin/xcodebuild", "-project", "Tests/FrameletAcceptance.xcodeproj", "-scheme", "FrameletAcceptance",
        "-configuration", "Debug", "-destination", "platform=macOS,arch=x86_64", "-derivedDataPath", str(root / "derived")]
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
    observer_handles = [(root / "originals-before.json").open("xb"), (root / "originals-before.stderr.txt").open("xb")]
    observer = subprocess.Popen([str(verifier), "snapshot", str(root / "capture-config.json")],
        env=environment, stdin=subprocess.DEVNULL, stdout=observer_handles[0], stderr=observer_handles[1], start_new_session=True)
    report["originalsObserver"] = {"pid": observer.pid, "readOnly": True, "startedBeforeNativeUI": True}
    ui_invoked = True
    run("native-ui", ["/usr/bin/xcodebuild", "test-without-building", "-xctestrun", str(run_file),
        "-destination", "platform=macOS,arch=x86_64", "-resultBundlePath", str(result),
        "-only-testing:FrameletAcceptance/FrameletCaptureAcceptance/testFUI03CapturePauseReopenAndExportOwnedWindow",
        "-parallel-testing-enabled", "NO", "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "240",
        "-maximum-test-execution-time-allowance", "300"], seconds=480, cwd=export)
    report["nativeTestCommandPassed"] = True
    report["fixtureHashesAfter"] = fixture_snapshot()
    assert report["fixtureHashesAfter"] == report["fixtureHashesBefore"]
    report["fixtureReadOnlyUnchanged"] = True
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
                assert case["testIdentifier"] == "FrameletCaptureAcceptance/testFUI03CapturePauseReopenAndExportOwnedWindow()"
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
                    match = re.fullmatch(r"(0[1-9]-[a-z0-9-]+|diagnostic-[a-z0-9-]+|capture-observations|capture-shutdown)_[0-9]+_([A-F0-9-]{36})\.(png|json|accessibility)", human)
                    entry = {"file": name, "name": human, "canonicalName": match[1] + "." + match[3] if match else None,
                        "bytes": path.stat().st_size, "sha256": digest.hexdigest(), "retainedInArtifact": True}
                    entries.append(entry)
                    if match or human.startswith(("App UI hierarchy", "UI Snapshot", "Complete Issue Description")):
                        raw = path.read_bytes(); total += len(raw)
                        assert len(raw) <= 2 * 1024 ** 2 and total <= 16 * 1024 ** 2
                        assert sha(raw) == entry["sha256"]
                        entry["gzipBase64"] = base64.b64encode(gzip.compress(raw, mtime=0)).decode()
            report["attachments"] = entries
            if report.get("nativeTestCommandPassed"):
                summary = report["testSummary"]
                assert summary["totalTestCount"] == summary["passedTests"] == 1 and summary["failedTests"] == summary["skippedTests"] == 0
                assert summary["result"] == "Passed" and not summary.get("testFailures")
                assert len(cases) == 1 and cases[0]["name"] == "testFUI03CapturePauseReopenAndExportOwnedWindow()" and cases[0]["result"] == "Passed"
                observations = [e for e in entries if e["canonicalName"] == "capture-observations.json"]
                assert len(observations) == 1
                observed = json.loads(gzip.decompress(base64.b64decode(observations[0]["gzipBase64"])))
                assert observed["caseId"] == "FUI03" and observed["status"] == "passed"
                assert observed["fixtureTitle"] == report["fixtureBinding"]["title"]
                assert observed["selectedSourceLabel"] == "Window: " + report["fixtureBinding"]["title"]
                assert observed["selectedSourceBeforeStart"] is True and observed["cameraMicrophoneSystemAudioOff"] is True
                assert observed["libraryHiddenForBothTakes"] is True and observed["reopenedClipCount"] == 2
                assert observed["nativeExportLabelObserved"] is True
                (root / "capture-observations.json").write_text(json.dumps(observed))
                report["uiObservations"] = observed
        except BaseException: report["errors"].append(traceback.format_exc())
    try:
        if observer is not None:
            cancelled = observer.poll() is None
            if cancelled:
                # This observer only reads finalized files. It owns no capture
                # or export writer; cancellation never targets the recorder.
                os.killpg(observer.pid, signal.SIGTERM)
            observer.wait(timeout=5)
            for handle in observer_handles: handle.close()
            row = {"exitCode": observer.returncode, "cancelledReadOnlyObserver": cancelled, "streams": {}}
            for name, file in (("stdout", "originals-before.json"), ("stderr", "originals-before.stderr.txt")):
                data = (root / file).read_bytes(); assert len(data) <= 65536
                row["streams"][name] = {"bytes": len(data), "sha256": sha(data), "complete": not cancelled,
                    "gzipBase64": base64.b64encode(gzip.compress(data, mtime=0)).decode()}
            report["originalsObserver"].update(row)
            if report.get("nativeTestCommandPassed"):
                assert observer.returncode == 0 and not cancelled
                report["fileVerification"] = json.loads(run("file-verification",
                    [str(verifier), "verify", str(root / "capture-config.json")], seconds=60))
                assert report["fileVerification"]["verified"] is True
    except BaseException: report["errors"].append(traceback.format_exc())
    try:
        assert source_guard() == baseline
        report["cleanup"]["sourceUnchanged"] = True
        shutdown = [e for e in report.get("attachments", []) if e["canonicalName"] == "capture-shutdown.json"]
        if ui_invoked:
            assert len(shutdown) == 1, "No UI shutdown acknowledgment; preserve live writers and scratch"
            acknowledgment = json.loads(gzip.decompress(base64.b64decode(shutdown[0]["gzipBase64"])))
            assert acknowledgment["caseId"] == "FUI03"
            report["shutdownAcknowledgment"] = acknowledgment
            safe = acknowledgment["safeToTerminate"] is True and acknowledgment["exportSettled"] is True
            if acknowledgment["captureRequested"]:
                safe = safe and acknowledgment["readyAndSourceControlsEnabled"] is True
            assert acknowledgment["forcedWriterTermination"] is False
        else:
            safe = True
            report["shutdownAcknowledgment"] = {"safeToTerminate": True, "nativeUINeverInvoked": True}
        report["cleanup"]["writersAcknowledgedBeforeCleanup"] = safe
    except BaseException:
        safe = False
        report["errors"].append(traceback.format_exc())
    # Preserve only authored library/media bytes, never builds/history/caches.
    # A live-writer snapshot is explicitly unfinalized; keep its original root.
    try:
        media_root = evidence / "authored-files"; media_root.mkdir(mode=0o700)
        retained = []; total = 0; inline_total = 0
        def retain(path, relative):
            global total, inline_total
            before = path.lstat()
            assert stat.S_ISREG(before.st_mode) and not path.is_symlink()
            assert path.resolve() == path and before.st_size <= 32 * 1024 ** 2
            with path.open("rb") as stream: data = stream.read(32 * 1024 ** 2 + 1)
            assert len(data) <= 32 * 1024 ** 2
            total += len(data); assert total <= 128 * 1024 ** 2 and len(retained) < 32
            destination = media_root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
            entry = {"path": relative, "bytes": len(data), "sha256": sha(data),
                "retainedInArtifact": True, "writersAcknowledged": safe}
            if len(data) <= 4 * 1024 ** 2 and inline_total + len(data) <= 8 * 1024 ** 2:
                inline_total += len(data)
                entry["gzipBase64"] = base64.b64encode(gzip.compress(data, mtime=0)).decode()
            retained.append(entry)
        if library_identity is not None:
            current = library.lstat()
            assert stat.S_ISDIR(current.st_mode) and not library.is_symlink()
            assert (current.st_dev, current.st_ino) == (library_identity.st_dev, library_identity.st_ino)
            assert (library / ".acceptance-owner").read_text() == nonce
            for p in sorted(library.rglob("*")):
                assert not p.is_symlink()
                if p.is_file(): retain(p, "library/" + str(p.relative_to(library)))
        for name in ("originals-before.json", "capture-observations.json", "authored-window-export.mp4"):
            p = root / name
            if p.is_file(): retain(p, name)
        for folder in root.glob(".framelet-export-*"):
            assert folder.is_dir() and not folder.is_symlink()
            for p in folder.rglob("*"):
                assert not p.is_symlink()
                if p.is_file(): retain(p, "partial-export/" + folder.name + "/" + str(p.relative_to(folder)))
        report["retainedAuthoredFiles"] = retained
        (evidence / "authored-files-state.json").write_text(json.dumps(retained, indent=2))
        report["cleanup"]["authoredFilesRetained"] = True
    except BaseException:
        safe = False
        report["errors"].append(traceback.format_exc())
    try:
        assert safe, "Unacknowledged writer or failed preservation: no app signals/library/scratch removal"
        def owned_processes():
            result = subprocess.run(["/bin/ps", "-axo", "pid=,command="], capture_output=True, timeout=10)
            assert result.returncode == 0 and len(result.stdout) <= 4 * 1024 ** 2
            rows = []
            for line in result.stdout.decode().splitlines():
                pair = line.strip().split(None, 1)
                if len(pair) == 2 and any(str(p) + "/" in pair[1] for p in (app, runner, fixture)):
                    rows.append({"pid": int(pair[0]), "command": pair[1]})
            return rows
        owned = owned_processes()
        report["cleanup"]["ownedProcessesBefore"] = owned
        for row in owned:
            check = subprocess.run(["/bin/ps", "-p", str(row["pid"]), "-o", "command="], capture_output=True, timeout=5)
            if check.returncode == 0 and check.stdout.decode().strip() == row["command"]:
                os.kill(row["pid"], signal.SIGTERM)
        if owned: time.sleep(1)
        remaining = owned_processes(); report["cleanup"]["ownedProcessesAfter"] = remaining
        assert not remaining
        report["cleanup"]["ownedAppAndRunnerAbsent"] = True
        if library_identity is not None:
            current = library.lstat()
            assert not library.is_symlink() and (current.st_dev, current.st_ino) == (library_identity.st_dev, library_identity.st_ino)
            assert (library / ".acceptance-owner").read_text() == nonce
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
    if report.get("nativeTestCommandPassed") and report.get("uiObservations") and report.get("fixtureReadOnlyUnchanged") and report.get("fileVerification", {}).get("verified") and not report["errors"]:
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
    assert len(data) <= 48 * 1024 ** 2
    (evidence / "receipt.json").write_bytes(data)
    print("FRAMELET_CAPTURE_RESULT=" + base64.b64encode(gzip.compress(data, mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
