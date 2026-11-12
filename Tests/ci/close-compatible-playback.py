"""Preserve one exact failed result packet and retire controls; no native rerun."""
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import subprocess
import tempfile
import time
import traceback
import urllib.request
import zipfile

repository = "alvarovillalbaa/framelet"
branch = "qa/framelet-compatible-closeout-20261112-1"
workflow_path = ".github/workflows/framelet-compatible-closeout-20261112-1.yml"
assert os.environ["GITHUB_REPOSITORY"] == repository and os.environ["GITHUB_REF"] == "refs/heads/" + branch
source, own_head = os.environ["FRAMELET_SOURCE_COMMIT"], os.environ["GITHUB_SHA"]
assert re.fullmatch(r"[0-9a-f]{40}", source) and re.fullmatch(r"[0-9a-f]{40}", own_head)
started = time.monotonic()
deadline = started + 180
sha = lambda b: hashlib.sha256(b).hexdigest()
report = {"kind": "framelet-compatible-playback-closeout", "source": source, "status": "failed",
    "requests": [], "errors": [], "appBuildOrNativeExecution": False}
target = None
root = None


def api(route, method="GET", expected=200, payload=None):
    assert time.monotonic() + 1 < deadline and len(report["requests"]) < 48
    timed_out = False
    try:
        args = ["gh", "api", "--include", "-H", "Cache-Control: no-cache", "--method", method,
            "repos/" + repository + "/" + route]
        if payload is not None: args.extend(["--input", "-"])
        command = subprocess.run(args, capture_output=True, input=json.dumps(payload).encode() if payload is not None else None,
            timeout=min(10, deadline - time.monotonic()))
        stdout, stderr, exit_code = command.stdout, command.stderr, command.returncode
    except subprocess.TimeoutExpired as error:
        stdout, stderr, exit_code = error.stdout or b"", error.stderr or b"", None
        timed_out = True
    retained_out, retained_err = stdout[:2 * 1024 ** 2], stderr[:65536]
    complete = not timed_out and len(stdout) == len(retained_out) and len(stderr) == len(retained_err)
    header, _, body = retained_out.replace(b"\r\n", b"\n").partition(b"\n\n")
    match = re.match(rb"HTTP/\S+ (\d{3})", header)
    status = int(match[1]) if match else None
    report["requests"].append({"route": route, "method": method, "status": status,
        "exitCode": exit_code, "timedOut": timed_out, "complete": complete,
        "stdoutBytes": len(retained_out), "stdoutSHA256": sha(retained_out), "observedStdoutBytes": len(stdout),
        "observedStdoutSHA256": sha(stdout), "stdoutGzipBase64": base64.b64encode(gzip.compress(retained_out, mtime=0)).decode(),
        "stderrBytes": len(retained_err), "stderrSHA256": sha(retained_err), "observedStderrBytes": len(stderr),
        "observedStderrSHA256": sha(stderr), "stderrGzipBase64": base64.b64encode(gzip.compress(retained_err, mtime=0)).decode()})
    assert complete and exit_code == 0 and status == expected, "Request rejected/incomplete; no retry"
    return json.loads(body) if body.strip() else None


def disabled(workflow):
    assert workflow["state"] in ("active", "disabled_manually")
    if workflow["state"] == "active":
        api("actions/workflows/" + str(workflow["id"]) + "/disable", "PUT", 204)
    for index in range(6):
        observed = api("actions/workflows/" + str(workflow["id"]))
        if observed["state"] == "disabled_manually":
            return observed
        assert observed["state"] == "active", "Unexpected state; stop"
        if index < 5:
            time.sleep(2)
    raise AssertionError("Disable not observed within bounded read-only state polling")


def remove_exact(ref, expected_head):
    matches = api("git/matching-refs/heads/" + ref)
    if not matches:
        return {"alreadyAbsent": True}
    assert len(matches) == 1 and matches[0]["ref"] == "refs/heads/" + ref
    assert matches[0]["object"]["sha"] == expected_head
    api("git/refs/heads/" + ref, "DELETE", 204)
    assert not api("git/matching-refs/heads/" + ref)
    return {"deletedHead": expected_head, "exactRefAbsent": True}


try:
    assert json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())["repository"]["private"] is False
    head = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, timeout=5)
    assert head.returncode == 0 and head.stdout.decode().strip() == source
    baseline = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], capture_output=True, timeout=5)
    assert baseline.returncode == 0 and not baseline.stdout
    raw = Path("docs/results/2026/11-12/compatible-playback-attempt-1.json").read_bytes()
    assert len(raw) == 3669957 and sha(raw) == "c3c2860438208f3e29797e8c7c49ec4719c323bed43fdd453477254750bc205e"
    native = json.loads(raw)
    assert native["status"] == "failed" and len(native["errors"]) == 1
    assert native["source"] == "6f9995351e24bf9acd175794e2772441f537a1e3"
    assert native["nativeTestCommandPassed"] and native["actualReleasedProcessVerified"] and native["fixtureReadOnlyUnchanged"]
    assert native["uiObservations"]["status"] == "passed" and len(native["uiObservations"]["phases"]) == 10
    assert all(native["cleanup"][key] is True for key in ("sourceAndIndexUnchanged", "releasedBundleUnchanged",
        "noCaptureAcknowledged", "ownedAppAndRunnerAbsent", "ownedLibraryAbsent", "ownedRootAbsent"))
    retired_raw = Path("docs/results/2026/11-12/compatible-playback-attempt-1-retirement.json").read_bytes()
    assert sha(retired_raw) == "3010d5eaca3032899557823d777f6b490190a30a7eff568869458778807b2002"
    retired = json.loads(retired_raw)
    assert retired["status"] == "failed" and len(retired["requests"]) == 3
    assert retired["requests"][-1]["route"] == "actions/artifacts/13969856158" and retired["requests"][-1]["status"] == 404
    candidate = api("actions/runs/43272020466")
    assert candidate["status"] == "completed" and candidate["conclusion"] == "failure"
    assert candidate["head_sha"] == "a211f88a7a5e2e245f7fc43c49149b38a25a1931" and candidate["workflow_id"] == 416339126
    assert candidate["head_branch"] == "qa/framelet-compatible-playback-20261112-1"
    jobs = api("actions/runs/43272020466/jobs")["jobs"]
    assert len(jobs) == 1 and jobs[0]["id"] == 131370737428 and jobs[0]["status"] == "completed"
    steps = {step["number"]: step for step in jobs[0]["steps"]}
    assert steps[3]["conclusion"] == steps[6]["conclusion"] == "failure" and steps[5]["conclusion"] == "success"
    # A current authorized collection, not a repeat of the rejected metadata URL.
    artifacts = api("actions/runs/43272020466/artifacts")["artifacts"]
    assert len(artifacts) == 1 and artifacts[0]["id"] == 13969856158
    artifact = artifacts[0]
    expected_digest = "e723317908e0b99fe7f5145f1f0ce53307e623badc11e71e232cde3726a99bbc"
    assert artifact["size_in_bytes"] == 7633128 and not artifact["expired"]
    assert artifact["digest"] == "sha256:" + expected_digest
    assert artifact["workflow_run"]["id"] == candidate["id"] and artifact["workflow_run"]["head_sha"] == candidate["head_sha"]
    target = candidate
    report["artifact"] = artifact
    report["failedVerdictPreserved"] = True
    parent = Path(os.environ["RUNNER_TEMP"]).resolve()
    root = Path(tempfile.mkdtemp(prefix="framelet-failed-packet-", dir=parent))
    root_identity = (root.stat().st_dev, root.stat().st_ino)
    archive = root / "framelet-compatible-playback-43272020466.zip"
    def limits():
        resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024 ** 2, 16 * 1024 ** 2))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    download = {"kind": "owned-read-only-artifact-download", "complete": False}
    report["artifactDownload"] = download
    try:
        with archive.open("xb") as output:
            process = subprocess.run(["gh", "api", "--method", "GET",
                "repos/" + repository + "/actions/artifacts/13969856158/zip"],
                stdout=output, stderr=subprocess.PIPE, timeout=min(30, deadline - time.monotonic()), preexec_fn=limits)
        download.update(exitCode=process.returncode, stderrBytes=len(process.stderr),
            stderrSHA256=sha(process.stderr), stderrGzipBase64=base64.b64encode(gzip.compress(process.stderr[:65536], mtime=0)).decode())
        assert process.returncode == 0 and len(process.stderr) <= 65536
        download["complete"] = True
    except subprocess.TimeoutExpired as error:
        stderr = error.stderr or b""
        download.update(exitCode=None, timedOut=True, stderrBytes=len(stderr), stderrSHA256=sha(stderr),
            stderrGzipBase64=base64.b64encode(gzip.compress(stderr[:65536], mtime=0)).decode())
        raise
    finally:
        if archive.exists():
            downloaded = archive.read_bytes()
            assert len(downloaded) <= 16 * 1024 ** 2
            download.update(bytes=len(downloaded), sha256=sha(downloaded))
    assert download["bytes"] == artifact["size_in_bytes"] and download["sha256"] == expected_digest
    with zipfile.ZipFile(archive) as packet:
        entries = packet.infolist()
        assert len(entries) <= 8192 and len({entry.filename for entry in entries}) == len(entries)
        assert sum(entry.file_size for entry in entries) <= 256 * 1024 ** 2
        assert packet.read("receipt.json") == raw
        assert any(entry.filename.startswith("ui.xcresult/") for entry in entries)
        report["packetStructure"] = {"entries": len(entries), "expandedBytes": sum(entry.file_size for entry in entries),
            "exactFailedReceiptVerified": True, "rawXcresultPresent": True}
    tag = "framelet-release-playback-evidence-20261112-attempt-1"
    assert not api("git/matching-refs/tags/" + tag)
    # gh accepts an exact structured request from stdin; retain the complete response.
    payload = {"tag_name": tag, "target_commitish": native["source"], "name": "Framelet 0.1.4 failed runtime evidence",
        "body": "Original failed native packet for run43272020466. All ten native interactions passed, but Recording preview pixels stayed black. Includes the exact raw xcresult, original screenshots/AX/streams/receipt and authored fixture inputs. This evidence preserves the failed verdict; no application release is qualified. SHA-256: " + expected_digest,
        "draft": True, "prerelease": True, "make_latest": "false"}
    report["evidenceTag"] = tag
    release = api("releases", "POST", 201, payload=payload)
    report["evidenceReleaseId"] = release["id"]
    timed_out = False
    try:
        upload = subprocess.run(["gh", "release", "upload", tag, str(archive), "--repo", repository],
            capture_output=True, timeout=min(30, deadline - time.monotonic()))
        stdout, stderr, exit_code = upload.stdout, upload.stderr, upload.returncode
    except subprocess.TimeoutExpired as error:
        stdout, stderr, exit_code, timed_out = error.stdout or b"", error.stderr or b"", None, True
    complete = not timed_out and len(stdout) <= 65536 and len(stderr) <= 65536
    report["uploadCommand"] = {"exitCode": exit_code, "complete": complete, "timedOut": timed_out,
        "stdoutBytes": len(stdout), "stdoutSHA256": sha(stdout),
        "stdoutGzipBase64": base64.b64encode(gzip.compress(stdout[:65536], mtime=0)).decode(),
        "stderrBytes": len(stderr), "stderrSHA256": sha(stderr),
        "stderrGzipBase64": base64.b64encode(gzip.compress(stderr[:65536], mtime=0)).decode()}
    assert exit_code == 0 and complete
    assets = api("releases/" + str(release["id"]) + "/assets")
    assert len(assets) == 1 and assets[0]["name"] == archive.name and assets[0]["size"] == 7633128
    assert assets[0]["digest"] == "sha256:" + expected_digest
    published = api("releases/" + str(release["id"]), "PATCH", payload={"draft": False, "make_latest": "false"})
    assert published["tag_name"] == tag and not published["draft"] and published["prerelease"]
    assert api("git/ref/tags/" + tag)["object"]["sha"] == native["source"]
    url = "https://github.com/" + repository + "/releases/download/" + tag + "/" + archive.name
    assert assets[0]["browser_download_url"] == url
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Framelet-failed-packet-preservation"}),
            timeout=min(30, deadline - time.monotonic())) as response:
        public_bytes = response.read(16 * 1024 ** 2 + 1)
        assert response.status == 200 and len(public_bytes) == 7633128 and sha(public_bytes) == expected_digest
    report["preservedPacket"] = {"url": url, "asset": assets[0], "anonymousStatus": 200,
        "bytes": len(public_bytes), "sha256": sha(public_bytes), "authenticated": False}
    report["packetPreservationVerified"] = True
except BaseException:
    report["errors"].append(traceback.format_exc())
finally:
    deadline = started + 240
    try:
        if target is not None:
            workflow = api("actions/workflows/416339126")
            assert workflow["path"] == ".github/workflows/framelet-compatible-playback-20261112-1.yml"
            report["targetObservedDisabled"] = disabled(workflow)["state"]
            report["targetBranch"] = remove_exact(target["head_branch"], target["head_sha"])
    except BaseException:
        report["errors"].append(traceback.format_exc())
    try:
        own = api("actions/runs/" + os.environ["GITHUB_RUN_ID"])
        assert own["head_sha"] == own_head and own["head_branch"] == branch
        own_workflow = api("actions/workflows/" + str(own["workflow_id"]))
        assert own_workflow["path"] == workflow_path
        report["ownObservedDisabled"] = disabled(own_workflow)["state"]
        report["ownWorkflow"] = own["workflow_id"]
        report["ownRun"] = own["id"]
        report["ownBranch"] = remove_exact(branch, own_head)
    except BaseException:
        report["errors"].append(traceback.format_exc())
    try:
        if root is not None:
            assert report.get("packetPreservationVerified") is True
            assert root.parent == parent and not root.is_symlink()
            assert (root.stat().st_dev, root.stat().st_ino) == root_identity
            assert {path.name for path in root.iterdir()} == {archive.name} and not archive.is_symlink()
            assert sha(archive.read_bytes()) == expected_digest
            shutil.rmtree(root); assert not root.exists()
        report["ownedRootAbsent"] = True
        after = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], capture_output=True, timeout=5)
        assert after.returncode == 0 and after.stdout == baseline.stdout
        report["sourceUnchanged"] = True
        report["nativeRerun"] = False
    except BaseException:
        report["errors"].append(traceback.format_exc())
    if (report.get("packetPreservationVerified") and report.get("targetObservedDisabled") == "disabled_manually"
            and report.get("ownObservedDisabled") == "disabled_manually" and report.get("sourceUnchanged")
            and report.get("ownedRootAbsent") and not report["errors"]):
        report["status"] = "passed"
    raw = json.dumps(report, separators=(",", ":")).encode()
    assert len(raw) <= 8 * 1024 ** 2
    print("FRAMELET_COMPATIBLE_PLAYBACK_CLOSEOUT=" + base64.b64encode(gzip.compress(raw, mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
