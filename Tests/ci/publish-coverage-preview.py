"""Publish0.1.5 retained assets plus the later playback qualification; data only."""
import base64
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
import time
import traceback
import urllib.error
import urllib.request

REPO = "alvarovillalbaa/framelet"
BRANCH = "qa/framelet-coverage-publish-20261112-1"
WORKFLOW = ".github/workflows/framelet-coverage-publish-20261112-1.yml"
TAG = "v0.1.5-preview.1"
PACKAGE_SOURCE = "0b2a03c0ac3af3c8c5605a5b4858b1136b43ec4c"
PACKAGE_SHA = "f5f2b70b3bd6976d307a772f05d6f918856c619bd379680ad7a6df8f93205bd5"
NATIVE_SOURCE = "6c4cdfe4e993af852ed43a59c150e4f8c425e7cf"
NATIVE_SHA = "24d39964807d36f7f6ac458af59ea10b35f0c97568ec637c77c1670b876b8f67"
RETIREMENT_SHA = "6a9116b9c6c71280abe87ac68d6b1dd166fc0a0bcd3274b1cb4ff5d4c9e8bbf8"
QUALIFICATION_SHA = "cb92b382af8c48bff74d8f45a8a96c1855e5acfaa535198257eff625414cb990"
OLD = json.loads("[{\"id\":438167998,\"tag\":\"v0.1.0-preview.1\",\"target\":\"05074098c1053a1d47e69ee9117b8338e1bcc8c2\",\"assets\":[{\"id\":723581535,\"name\":\"Framelet-0.1.0-macos-universal.zip\",\"size\":1157438,\"digest\":\"sha256:c84865b23c93113114f44d7cbff17f19ca661905f2a1ca0f8f18a2b02ef1e76a\"},{\"id\":723581604,\"name\":\"Framelet-0.1.0-macos-universal.zip.sha256\",\"size\":101,\"digest\":\"sha256:1435dfc7a21632d75242cdc0a87c0ed226cafb40e0c0ac2907ad824e94fc6ffa\"},{\"id\":723581621,\"name\":\"Framelet-preview-manifest.json\",\"size\":1735,\"digest\":\"sha256:3f899233af08cb19567100fa9a0cd5c47d7d652bf8f8f3ac957771a6b29750f2\"}]},{\"id\":442693072,\"tag\":\"framelet-ui-evidence-20261112-attempt-5\",\"target\":\"a65b02697adba86b49ea730dd02e7eec0b281110\",\"assets\":[{\"id\":738757493,\"name\":\"framelet-native-ui-attempt-5.zip\",\"size\":98057941,\"digest\":\"sha256:c9e8a9831198623d7673ed096dc59c02eeae48859101211c0d1a928305d33496\"}]},{\"id\":442765166,\"tag\":\"v0.1.1-preview.1\",\"target\":\"618cabda9b08b04604dbb7992e8c4f73ff9606a8\",\"assets\":[{\"id\":738972227,\"name\":\"Framelet-0.1.1-macos-universal.zip\",\"size\":1159292,\"digest\":\"sha256:0a02be066db9936c35decab2b32e4892cbf1c75b97ed3d2188c0abc420a78fce\"},{\"id\":738972230,\"name\":\"Framelet-0.1.1-macos-universal.zip.sha256\",\"size\":101,\"digest\":\"sha256:f7631379c8b09a575a5016967254336237cc85c18a6e9716cbb4be378edd57dc\"},{\"id\":738972234,\"name\":\"Framelet-preview-manifest.json\",\"size\":2617,\"digest\":\"sha256:a05a21480e2df7852911a09b16f6f4fc378f1d4901de2c4022eff164e6158bd5\"}]},{\"id\":442850113,\"tag\":\"v0.1.2-preview.1\",\"target\":\"5d6e55447e372e5b9ea510ebebf85738f6e6bc24\",\"assets\":[{\"id\":739217605,\"name\":\"Framelet-0.1.2-macos-universal.zip\",\"size\":1161342,\"digest\":\"sha256:3bb344ec7978b6cddbaf14100534338b8413ce9c398ceef22d967786788ea648\"},{\"id\":739217607,\"name\":\"Framelet-preview-manifest.json\",\"size\":2399,\"digest\":\"sha256:4f9d3022c831faa27ff26d48872b849cabe50dd79499a72f7c27f0f60b528446\"},{\"id\":739217608,\"name\":\"Framelet-0.1.2-macos-universal.zip.sha256\",\"size\":101,\"digest\":\"sha256:cd829a7b5e7576164c7b44d1fc7b4e0bbbe40eab89a48a360012f334aa830959\"}]},{\"id\":443023863,\"tag\":\"v0.1.3-preview.1\",\"target\":\"8486e830810699eb14786d7c8ce2780efb069bee\",\"assets\":[{\"id\":739696748,\"name\":\"Framelet-0.1.3-macos-universal.zip\",\"size\":1162196,\"digest\":\"sha256:b4c0d15b6f89ba0df9645f3ea6f92b4a2b18ed3b5ac34b2ee8bd4a56fbadbccd\"},{\"id\":739696749,\"name\":\"Framelet-0.1.3-macos-universal.zip.sha256\",\"size\":101,\"digest\":\"sha256:0583066cb8538090366ef708a57f669c69a7635dc65915d512baab265c54c25c\"},{\"id\":739696752,\"name\":\"Framelet-preview-manifest.json\",\"size\":2789,\"digest\":\"sha256:bec73ac46eea5a9d88a177ff1e105ae3f7a16c40d25bb5c22195f2ef7fd12b51\"}]},{\"id\":443326502,\"tag\":\"framelet-release-playback-evidence-20261112-attempt-1\",\"target\":\"6f9995351e24bf9acd175794e2772441f537a1e3\",\"assets\":[{\"id\":740519926,\"name\":\"framelet-compatible-playback-43272020466.zip\",\"size\":7633128,\"digest\":\"sha256:e723317908e0b99fe7f5145f1f0ce53307e623badc11e71e232cde3726a99bbc\"}]}]")
assert os.environ["GITHUB_REPOSITORY"] == REPO and os.environ["GITHUB_REF"] == "refs/heads/" + BRANCH
SOURCE, OWN_HEAD = os.environ["FRAMELET_SOURCE_COMMIT"], os.environ["GITHUB_SHA"]
assert re.fullmatch(r"[0-9a-f]{40}", SOURCE) and re.fullmatch(r"[0-9a-f]{40}", OWN_HEAD)
os.environ["GIT_OPTIONAL_LOCKS"] = "0"
os.umask(0o077)
started = time.monotonic()
closing = False
report = {"kind": "framelet-coverage-publication", "source": SOURCE, "status": "failed",
    "commands": [], "requests": [], "errors": [], "applicationBuildOrTestsExecuted": False}
root = None
admitted = False
tracked = {}
sha = lambda raw: hashlib.sha256(raw).hexdigest()
MIB = 1024 ** 2


def command(name, args, seconds=15, data=None):
    remaining = started + (450 if closing else 360) - time.monotonic()
    assert remaining > 1
    timed_out = False
    try:
        child = subprocess.run(args, input=data, capture_output=True, timeout=min(seconds, remaining))
        out, err, code = child.stdout, child.stderr, child.returncode
    except subprocess.TimeoutExpired as error:
        out, err, code, timed_out = error.stdout or b"", error.stderr or b"", None, True
    row = {"name": name, "args": args, "exitCode": code, "timedOut": timed_out, "streams": {}}
    for label, raw in (("stdout", out), ("stderr", err)):
        retained = raw[:2 * MIB]
        row["streams"][label] = {"bytes": len(retained), "sha256": sha(retained),
            "observedBytes": len(raw), "observedSHA256": sha(raw),
            "complete": not timed_out and len(retained) == len(raw),
            "gzipBase64": base64.b64encode(gzip.compress(retained, mtime=0)).decode()}
    if data is not None:
        assert len(data) <= 65536
        row["stdin"] = {"bytes": len(data), "sha256": sha(data),
            "gzipBase64": base64.b64encode(gzip.compress(data, mtime=0)).decode()}
    assert len(report["commands"]) < 80
    report["commands"].append(row)
    return row, out, err


def succeeded(row):
    return row["exitCode"] == 0 and not row["timedOut"] and all(s["complete"] for s in row["streams"].values())


def api(route, method="GET", expected=200, payload=None):
    assert len(report["requests"]) < 64
    args = ["gh", "api", "--include", "-H", "Cache-Control: no-cache", "--method", method, "repos/" + REPO + "/" + route]
    data = None
    if payload is not None:
        args += ["--input", "-"]; data = json.dumps(payload, separators=(",", ":")).encode()
    row, out, _ = command("api-" + method + "-" + route, args, data=data)
    header, _, body = out.replace(b"\r\n", b"\n").partition(b"\n\n")
    match = re.match(rb"HTTP/\S+ (\d{3})", header)
    status = int(match[1]) if match else None
    report["requests"].append({"route": route, "method": method, "status": status, "commandIndex": len(report["commands"]) - 1})
    assert succeeded(row) and status == expected, "Rejected/incomplete request; no retry"
    return json.loads(body) if body.strip() else None


def source_snapshot():
    row, head, _ = command("source-head", ["git", "rev-parse", "HEAD"])
    assert succeeded(row) and head.decode().strip() == SOURCE
    row, status, _ = command("source-status", ["git", "status", "--porcelain", "--untracked-files=all", "--ignored"])
    assert succeeded(row) and not status
    row, tree, _ = command("source-tree", ["git", "ls-tree", "-rz", "--full-tree", "HEAD"])
    assert succeeded(row)
    vector, total = {}, 0
    for entry in filter(None, tree.split(b"\0")):
        meta, raw_name = entry.split(b"\t", 1)
        mode, kind, oid = meta.split(); name = raw_name.decode()
        path = Path(name); value = path.lstat()
        assert kind == b"blob" and mode in (b"100644", b"100755") and stat.S_ISREG(value.st_mode)
        assert not path.is_symlink() and value.st_size <= 48 * MIB and bool(value.st_mode & 0o111) == (mode == b"100755")
        total += value.st_size; assert len(vector) < 1024 and total <= 256 * MIB
        git_hash = hashlib.sha1(b"blob " + str(value.st_size).encode() + b"\0"); digest = hashlib.sha256()
        with path.open("rb") as stream:
            for part in iter(lambda: stream.read(65536), b""):
                git_hash.update(part); digest.update(part)
        assert git_hash.hexdigest() == oid.decode()
        vector[name] = {"mode": mode.decode(), "blob": oid.decode(), "bytes": value.st_size, "sha256": digest.hexdigest()}
    return {"files": vector, "indexSHA256": sha(Path(".git/index").read_bytes())}


def preserved_assets():
    observed = []
    for pin in OLD:
        release = api("releases/" + str(pin["id"]))
        assert not release["draft"] and release["tag_name"] == pin["tag"]
        assert api("git/ref/tags/" + pin["tag"])["object"]["sha"] == pin["target"]
        assets = sorted([{"id": a["id"], "name": a["name"], "size": a["size"], "digest": a["digest"]} for a in release["assets"]], key=lambda a: a["id"])
        assert assets == pin["assets"]
        observed.append({"id": release["id"], "tag": pin["tag"], "target": pin["target"], "assets": assets})
    assert len(observed) == 6 and sum(len(row["assets"]) for row in observed) == 14
    return observed


def read_pinned(name, digest, maximum):
    path = Path("docs/results/2026/11-12") / name
    assert path.is_file() and not path.is_symlink() and path.stat().st_size <= maximum
    raw = path.read_bytes(); assert sha(raw) == digest
    return raw


def write_owned(name, raw):
    assert Path(name).name == name and name not in (".", "..") and name not in tracked
    path = root / name
    with path.open("xb") as stream: stream.write(raw)
    tracked[name] = {"bytes": len(raw), "sha256": sha(raw)}


def bounded_root():
    assert root.parent == parent and not root.is_symlink() and (root.stat().st_dev, root.stat().st_ino) == root_identity
    paths = list(root.iterdir())
    assert len(paths) <= 16 and {p.name for p in paths} == set(tracked)
    logical = allocated = 0
    for path in paths:
        value = path.lstat()
        assert stat.S_ISREG(value.st_mode) and value.st_nlink == 1 and value.st_uid == os.getuid() and not path.is_symlink()
        logical += value.st_size; allocated += value.st_blocks * 512
    assert logical <= 32 * MIB and allocated <= 32 * MIB
    report["maxOwnedBytes"] = max(logical, report.get("maxOwnedBytes", 0))
    report["maxOwnedAllocatedBytes"] = max(allocated, report.get("maxOwnedAllocatedBytes", 0))


try:
    before = source_snapshot(); report["sourceBefore"] = before
    own = api("actions/runs/" + os.environ["GITHUB_RUN_ID"])
    workflow = api("actions/workflows/" + str(own["workflow_id"]))
    assert own["head_sha"] == OWN_HEAD and own["head_branch"] == BRANCH and workflow["path"] == WORKFLOW
    assert workflow["state"] == "active"
    assert json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())["repository"]["private"] is False
    admitted = True
    package = json.loads(read_pinned("coverage-preview-attempt-1.json", PACKAGE_SHA, 16 * MIB))
    native = json.loads(read_pinned("coverage-playback-attempt-1.json", NATIVE_SHA, 48 * MIB))
    retired = json.loads(read_pinned("coverage-playback-attempt-1-retirement.json", RETIREMENT_SHA, 8 * MIB))
    qualification_raw = read_pinned("coverage-playback-qualification.json", QUALIFICATION_SHA, 8192)
    qualification = json.loads(qualification_raw)
    assert package["sourceCommit"] == PACKAGE_SOURCE and package["status"] == "passed" and package["cleanup"]["verified"] and package["cleanup"]["rootAbsent"]
    assert not package["ownedSignals"] and not package["applicationLaunched"] and not package["testsExecuted"]
    for name, row in package["sourceVector"].items():
        if name == "Package.swift" or name.startswith(("Sources/", "Resources/", "script/", "Tests/")):
            assert before["files"][name]["sha256"] == row["sha256"]
    assert native["source"] == NATIVE_SOURCE and native["status"] == "passed" and not native["errors"]
    assert native["nativeTestCommandPassed"] and native["actualReleasedProcessVerified"] and native["fixtureReadOnlyUnchanged"]
    assert native["pixelVerification"]["verified"] and native["pixelVerification"]["pixelPhasesVerified"] == 9
    assert len(native["uiObservations"]["phases"]) == 10 and native["testSummary"]["passedTests"] == native["testSummary"]["totalTestCount"] == 1
    assert all(native["testSummary"][key] == 0 for key in ("failedTests", "skippedTests", "expectedFailures"))
    assert all(native["cleanup"][key] is True for key in ("sourceAndIndexUnchanged", "releasedBundleUnchanged", "noCaptureAcknowledged",
        "authoredInputsRetained", "ownedAppAndRunnerAbsent", "ownedLibraryAbsent", "ownedRootAbsent", "passingRawResultIntermediateRemoved"))
    assert not native["cleanup"]["ownedProcessesAfter"] and native["sourceGuards"][0] == native["sourceGuards"][-1]
    assert native["releasedBundleBefore"] == native["releasedBundleAfter"] and native["fixtureHashesBefore"] == native["fixtureHashesAfter"]
    for row in native["sourceGuards"][0]:
        if row["path"] == "Package.swift" or row["path"].startswith(("Sources/", "Resources/", "script/", "Tests/")):
            assert before["files"][row["path"]]["sha256"] == row["sha256"]
    assert native["releasedSourceAndRuntimeInputs"]["source"] == PACKAGE_SOURCE and native["releasedSourceAndRuntimeInputs"]["receiptSHA256"] == PACKAGE_SHA
    assert retired["status"] == "passed" and not retired["errors"] and retired["observedDisabled"] == "disabled_manually"
    assert retired["exactRefAbsent"] and retired["uploadedEvidenceRemoved"]
    assert qualification["packageSource"] == PACKAGE_SOURCE and qualification["packageReceiptSHA256"] == PACKAGE_SHA
    q = qualification["releasePlayback"]
    assert q["verified"] and q["source"] == NATIVE_SOURCE and q["receiptSHA256"] == NATIVE_SHA and q["retirementReceiptSHA256"] == RETIREMENT_SHA
    assert q["nativePhaseCount"] == 10 and q["pixelPhaseCount"] == 9 and q["architecture"] == native["nativeProfile"]["architecture"] == "x86_64"
    assert q["macOS"] == native["nativeProfile"]["macOS"] and q["run"] == 43298428068
    assert q["runURL"] == "https://github.com/alvarovillalbaa/framelet/actions/runs/43298428068"
    assert q["exactReleasedProcessVerified"] and q["originalInputsUnchanged"] and q["ownedCleanupVerified"] and q["controlRetired"]
    names = {"Framelet-0.1.5-macos-universal.zip", "Framelet-0.1.5-macos-universal.zip.sha256", "Framelet-preview-manifest.json"}
    assert set(package["retainedOriginals"]) == names
    report["oldAssetsBefore"] = preserved_assets()
    assert not api("git/matching-refs/tags/" + TAG)
    parent = Path(os.environ["RUNNER_TEMP"]).resolve()
    root = Path(tempfile.mkdtemp(prefix="framelet-coverage-publication-", dir=parent))
    root_identity = (root.stat().st_dev, root.stat().st_ino)
    write_owned("owner", os.urandom(24).hex().encode())
    for name, item in package["retainedOriginals"].items():
        with gzip.GzipFile(fileobj=io.BytesIO(base64.b64decode(item["gzipBase64"], validate=True))) as compressed:
            raw = compressed.read(8 * MIB + 1)
        assert len(raw) == item["bytes"] <= 8 * MIB and sha(raw) == item["sha256"]
        write_owned(name, raw)
    write_owned("Framelet-playback-qualification.json", qualification_raw)
    names.add("Framelet-playback-qualification.json")
    files = {name: tracked[name] for name in sorted(names)}; report["assets"] = files
    manifest = json.loads((root / "Framelet-preview-manifest.json").read_bytes())
    assert manifest["version"] == qualification["version"] == "0.1.5" and manifest["build"] == qualification["build"] == "6"
    assert manifest["sourceCommit"] == PACKAGE_SOURCE and manifest["archive"] == qualification["archive"]
    assert manifest["archive"]["sha256"] == native["releasedArchive"]["sha256"] == files[manifest["archive"]["name"]]["sha256"]
    assert (root / (manifest["archive"]["name"] + ".sha256")).read_bytes() == (manifest["archive"]["sha256"] + "  " + manifest["archive"]["name"] + "\n").encode()
    bounded_root()
    body = ("Fixes black Recording previews caused by a tiny gap at the end of composition instructions. "
        "The exact universal Release archive passed the complete playback journey and nine rendered-color checks on an Intel macOS15 VM: "
        "play/pause, continuous take boundary, seeks, Selected Clip reset, end/replay and normal Quit/reopen. "
        "Both arm64/x86_64 Release slices and fresh ZIP/signature checks passed. "
        "The separate playback qualification records this later native result; the build manifest describes packaging-time checks. "
        "Requires macOS15+. Ad-hoc developer preview, without Developer ID/notarization. "
        "ARM runtime, physical devices, real camera/audio timing, migration, human accessibility and trusted downloaded-app launch remain unverified. "
        "No cloud account or paid service is required.\n\n"
        "Playback evidence: https://github.com/alvarovillalbaa/framelet/actions/runs/43298428068")
    release = api("releases", "POST", 201, {"tag_name": TAG, "target_commitish": PACKAGE_SOURCE,
        "name": "Framelet 0.1.5 developer preview", "body": body, "draft": True, "prerelease": True, "make_latest": "false"})
    report["releaseId"] = release["id"]
    row, _, _ = command("upload-four-exact-assets", ["gh", "release", "upload", TAG, *[str(root / name) for name in sorted(names)], "--repo", REPO], seconds=90)
    assert succeeded(row)
    assets = api("releases/" + str(release["id"]) + "/assets")
    assert len(assets) == 4 and {a["name"] for a in assets} == names
    for asset in assets: assert asset["size"] == files[asset["name"]]["bytes"] and asset["digest"] == "sha256:" + files[asset["name"]]["sha256"]
    published = api("releases/" + str(release["id"]), "PATCH", payload={"draft": False, "make_latest": "false"})
    assert not published["draft"] and published["prerelease"] and published["tag_name"] == TAG
    assert api("git/ref/tags/" + TAG)["object"]["sha"] == PACKAGE_SOURCE
    fresh = api("releases/" + str(release["id"]))
    assert not fresh["draft"] and fresh["prerelease"] and fresh["tag_name"] == TAG and len(fresh["assets"]) == 4
    assert {asset["name"] for asset in fresh["assets"]} == names
    assert all(asset["size"] == files[asset["name"]]["bytes"] and asset["digest"] == "sha256:" + files[asset["name"]]["sha256"] for asset in fresh["assets"])
    report.update(tag=TAG, releaseURL=fresh["html_url"], serverAssets=fresh["assets"], anonymousDownloads=[])
    for asset in fresh["assets"]:
        name = asset["name"]; assert name in names
        url = "https://github.com/" + REPO + "/releases/download/" + TAG + "/" + name
        assert asset["browser_download_url"] == url
        request = urllib.request.Request(url, headers={"User-Agent": "Framelet-exact-asset-delivery"})
        assert {key.lower() for key, _ in request.header_items()} == {"user-agent"}
        item = {"name": name, "url": url, "authenticated": False, "complete": False, "status": None}
        report["anonymousDownloads"].append(item); raw = bytearray()
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                item["status"] = response.status; assert response.status == 200
                while True:
                    assert time.monotonic() < started + 360
                    part = response.read(min(65536, 8 * MIB + 1 - len(raw)))
                    if not part: item["complete"] = True; break
                    raw.extend(part); assert len(raw) <= 8 * MIB
        except BaseException as error:
            if isinstance(error, urllib.error.HTTPError): item["status"] = error.code
            item["error"] = traceback.format_exc()
            raise
        finally:
            data = bytes(raw); item.update(bytes=len(data), sha256=sha(data))
            if not item["complete"] or len(data) != files[name]["bytes"] or sha(data) != files[name]["sha256"]:
                item["partialGzipBase64"] = base64.b64encode(gzip.compress(data, mtime=0)).decode()
            write_owned("download-" + name, data)
        assert item["complete"] and item["bytes"] == files[name]["bytes"] and item["sha256"] == files[name]["sha256"]
        item["bodyEqualsUploadedOriginal"] = True
        bounded_root()
    report["oldAssetsAfter"] = preserved_assets()
    assert report["oldAssetsAfter"] == report["oldAssetsBefore"]
    report["deliveryVerified"] = True
except BaseException:
    report["errors"].append(traceback.format_exc())
finally:
    closing = True
    try:
        if root is not None:
            bounded_root()
            for path in root.iterdir():
                assert path.stat().st_size == tracked[path.name]["bytes"] and sha(path.read_bytes()) == tracked[path.name]["sha256"]
            shutil.rmtree(root); assert not root.exists()
        report["ownedRootAbsent"] = True
    except BaseException: report["errors"].append(traceback.format_exc())
    try:
        assert admitted, "No admitted exact workflow; no retirement mutation"
        assert api("git/ref/heads/" + BRANCH)["object"]["sha"] == OWN_HEAD
        workflow = api("actions/workflows/" + str(own["workflow_id"]))
        assert workflow["path"] == WORKFLOW and workflow["state"] in ("active", "disabled_manually")
        if workflow["state"] == "active": api("actions/workflows/" + str(workflow["id"]) + "/disable", "PUT", 204)
        for index in range(6):
            state = api("actions/workflows/" + str(workflow["id"]))["state"]
            if state == "disabled_manually": break
            assert state == "active"
            if index < 5: time.sleep(2)
        assert state == "disabled_manually"
        assert api("git/ref/heads/" + BRANCH)["object"]["sha"] == OWN_HEAD
        api("git/refs/heads/" + BRANCH, "DELETE", 204)
        assert not api("git/matching-refs/heads/" + BRANCH)
        report["controlRetirement"] = {"workflow": workflow["id"], "disabledState": state, "deletedHead": OWN_HEAD, "exactRefAbsent": True}
    except BaseException: report["errors"].append(traceback.format_exc())
    try:
        report["sourceAfter"] = source_snapshot()
        assert report["sourceAfter"] == before
        report["sourceAndIndexUnchanged"] = True
    except BaseException: report["errors"].append(traceback.format_exc())
    if report.get("deliveryVerified") and report.get("ownedRootAbsent") and report.get("sourceAndIndexUnchanged") and report.get("controlRetirement", {}).get("exactRefAbsent") and not report["errors"]:
        report["status"] = "passed"
    report["elapsedSeconds"] = time.monotonic() - started
    raw = json.dumps(report, separators=(",", ":")).encode()
    assert len(raw) <= 16 * MIB
    print("FRAMELET_COVERAGE_PUBLICATION=" + base64.b64encode(gzip.compress(raw, mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
