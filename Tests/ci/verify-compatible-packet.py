"""Fresh public failed-packet delivery verification; no upload or native rerun."""
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import traceback
import urllib.error
import urllib.request
import zipfile

repository = "alvarovillalbaa/framelet"
branch = "qa/framelet-compatible-packet-20261112-1"
workflow_path = ".github/workflows/framelet-compatible-packet-20261112-1.yml"
assert os.environ["GITHUB_REPOSITORY"] == repository and os.environ["GITHUB_REF"] == "refs/heads/" + branch
source, own_head = os.environ["FRAMELET_SOURCE_COMMIT"], os.environ["GITHUB_SHA"]
assert re.fullmatch(r"[0-9a-f]{40}", source) and re.fullmatch(r"[0-9a-f]{40}", own_head)
started = time.monotonic()
deadline = started + 70
sha = lambda b: hashlib.sha256(b).hexdigest()
report = {"kind": "framelet-compatible-packet-verification", "source": source, "status": "failed",
    "requests": [], "errors": [], "appBuildOrNativeExecution": False}
root = None


def api(route, method="GET", expected=200):
    assert time.monotonic() + 1 < deadline and len(report["requests"]) < 48
    timed_out = False
    try:
        command = subprocess.run(["gh", "api", "--include", "-H", "Cache-Control: no-cache", "--method", method,
            "repos/" + repository + "/" + route], capture_output=True,
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
    index_before = sha(Path(".git/index").read_bytes())
    failed_raw = Path("docs/results/2026/11-12/compatible-playback-closeout-attempt-1.json").read_bytes()
    assert sha(failed_raw) == "b4d7e94fb0cab4774f2d054d5851f1d59268774e030374ecafe0c430b67efcd6"
    failed = json.loads(failed_raw)
    assert failed["status"] == "failed" and failed["evidenceReleaseId"] == 443326502
    assert failed["targetObservedDisabled"] == failed["ownObservedDisabled"] == "disabled_manually"
    release = api("releases/443326502")
    tag = "framelet-release-playback-evidence-20261112-attempt-1"
    assert release["tag_name"] == tag and not release["draft"] and release["prerelease"]
    assert api("git/ref/tags/" + tag)["object"]["sha"] == "6f9995351e24bf9acd175794e2772441f537a1e3"
    assert len(release["assets"]) == 1
    asset = release["assets"][0]
    digest = "e723317908e0b99fe7f5145f1f0ce53307e623badc11e71e232cde3726a99bbc"
    assert asset["id"] == 740519926 and asset["name"] == "framelet-compatible-playback-43272020466.zip"
    assert asset["size"] == 7633128 and asset["digest"] == "sha256:" + digest
    report["serverAsset"] = asset
    for workflow_id, path, ref in (
        (416339126, ".github/workflows/framelet-compatible-playback-20261112-1.yml", "qa/framelet-compatible-playback-20261112-1"),
        (416360873, ".github/workflows/framelet-compatible-closeout-20261112-1.yml", "qa/framelet-compatible-closeout-20261112-1")):
        workflow = api("actions/workflows/" + str(workflow_id))
        assert workflow["path"] == path and workflow["state"] == "disabled_manually"
        assert not api("git/matching-refs/heads/" + ref)
    report["priorControlsReadOnlyVerified"] = True
    parent = Path(os.environ["RUNNER_TEMP"]).resolve()
    root = Path(tempfile.mkdtemp(prefix="framelet-public-packet-", dir=parent))
    root_identity = (root.stat().st_dev, root.stat().st_ino)
    archive = root / asset["name"]
    url = "https://github.com/" + repository + "/releases/download/" + tag + "/" + archive.name
    assert asset["browser_download_url"] == url
    request = urllib.request.Request(url, headers={"User-Agent": "Framelet-failed-packet-delivery"})
    assert {name.lower() for name, _ in request.header_items()} == {"user-agent"}
    report["anonymousDownload"] = download = {"url": url, "authenticated": False,
        "complete": False, "status": None, "requestHeaders": dict(request.header_items())}
    observed = hashlib.sha256()
    count = 0
    try:
        with archive.open("xb") as output, urllib.request.urlopen(request, timeout=min(30, deadline - time.monotonic())) as response:
            download["status"] = response.status
            assert response.status == 200
            while True:
                assert time.monotonic() < deadline
                part = response.read(min(65536, 16 * 1024 ** 2 + 1 - count))
                if not part:
                    download["complete"] = True; break
                count += len(part); observed.update(part)
                assert count <= 16 * 1024 ** 2
                output.write(part)
    except BaseException as error:
        if isinstance(error, urllib.error.HTTPError): download["status"] = error.code
        download["error"] = traceback.format_exc()
        raise
    finally:
        download.update(bytes=count, sha256=observed.hexdigest())
    assert download["complete"] and count == 7633128 and observed.hexdigest() == digest
    raw_native = Path("docs/results/2026/11-12/compatible-playback-attempt-1.json").read_bytes()
    assert sha(raw_native) == "c3c2860438208f3e29797e8c7c49ec4719c323bed43fdd453477254750bc205e"
    with zipfile.ZipFile(archive) as packet:
        entries = packet.infolist()
        assert len(entries) == 136 and sum(entry.file_size for entry in entries) == 10032216
        assert packet.read("receipt.json") == raw_native and any(entry.filename.startswith("ui.xcresult/") for entry in entries)
    report["rawFailedPacketVerified"] = True
    report["oldFailuresAndEndedVMScratchGapsUnchanged"] = True
except BaseException:
    report["errors"].append(traceback.format_exc())
finally:
    deadline = started + 100
    try:
        if root is not None:
            assert report.get("rawFailedPacketVerified")
            assert root.parent == parent and not root.is_symlink()
            assert (root.stat().st_dev, root.stat().st_ino) == root_identity
            assert {path.name for path in root.iterdir()} == {archive.name} and not archive.is_symlink()
            assert sha(archive.read_bytes()) == digest
            shutil.rmtree(root); assert not root.exists()
        report["ownedDuplicateRootAbsent"] = True
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
        after = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], capture_output=True, timeout=5)
        assert after.returncode == 0 and after.stdout == baseline.stdout and sha(Path(".git/index").read_bytes()) == index_before
        report["sourceAndIndexUnchanged"] = True
    except BaseException:
        report["errors"].append(traceback.format_exc())
    if (report.get("rawFailedPacketVerified") and report.get("ownedDuplicateRootAbsent")
            and report.get("ownObservedDisabled") == "disabled_manually" and report.get("sourceAndIndexUnchanged")
            and not report["errors"]):
        report["status"] = "passed"
    raw = json.dumps(report, separators=(",", ":")).encode()
    assert len(raw) <= 8 * 1024 ** 2
    print("FRAMELET_COMPATIBLE_PACKET_VERIFICATION=" + base64.b64encode(gzip.compress(raw, mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
