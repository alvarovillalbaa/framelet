"""Data-only exact control closeout. No app, build, native test or artifact write."""
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import traceback

repository = "alvarovillalbaa/framelet"
branch = "qa/framelet-composition-retirement-20261112-1"
workflow_path = ".github/workflows/framelet-composition-retirement-20261112-1.yml"
assert os.environ["GITHUB_REPOSITORY"] == repository and os.environ["GITHUB_REF"] == "refs/heads/" + branch
source, own_head = os.environ["FRAMELET_SOURCE_COMMIT"], os.environ["GITHUB_SHA"]
assert re.fullmatch(r"[0-9a-f]{40}", source) and re.fullmatch(r"[0-9a-f]{40}", own_head)
deadline = time.monotonic() + 100
sha = lambda b: hashlib.sha256(b).hexdigest()
report = {"kind": "framelet-composition-retirement-closeout", "source": source, "status": "failed",
    "requests": [], "errors": [], "appBuildOrNativeExecution": False}


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
    raw = Path("docs/results/2026/11-12/composition-probe-attempt-3.json").read_bytes()
    assert len(raw) == 735731 and sha(raw) == "278c5a1eb3d3b936f3103e2d16189818b310ca33ccc72e2211d34994a2ec5595"
    native = json.loads(raw)
    assert native["status"] == "passed" and not native["errors"] and native["diagnosticOnly"] is True
    assert native["source"] == "c4a740687047d0f67c8d24520db52d5a7164fd69"
    assert all(native["cleanup"][key] is True for key in ("sourceAndIndexUnchanged", "releasedBundleUnchanged",
        "noCaptureAcknowledged", "ownedAppAndRunnerAbsent", "ownedLibraryAbsent", "ownedRootAbsent"))
    target = api("actions/runs/43253033480")
    assert target["status"] == "completed" and target["conclusion"] == "failure"
    assert target["head_sha"] == "eaf30d07051525b2bbeb38ffbc7d1f3223893fab" and target["workflow_id"] == 416220974
    assert target["head_branch"] == "qa/framelet-composition-probe-20261112-3"
    jobs = api("actions/runs/43253033480/jobs")["jobs"]
    assert len(jobs) == 1 and jobs[0]["id"] == 131303740674 and jobs[0]["status"] == "completed"
    steps = {step["number"]: step for step in jobs[0]["steps"]}
    assert steps[3]["conclusion"] == steps[5]["conclusion"] == "success" and steps[6]["conclusion"] == "failure"
    artifact = api("actions/artifacts/13959324008")
    assert artifact["size_in_bytes"] == 825196 and not artifact["expired"]
    assert artifact["digest"] == "sha256:99fc4ed4b355621f6aa69dbc18e7c6e04186a27646248666ae69b721d3cb13ac"
    assert artifact["workflow_run"]["id"] == target["id"] and artifact["workflow_run"]["head_sha"] == target["head_sha"]
    workflow = api("actions/workflows/416220974")
    assert workflow["path"] == ".github/workflows/framelet-composition-probe-20261112-3.yml"
    report["targetObservedDisabled"] = disabled(workflow)["state"]
    report["targetBranch"] = remove_exact(target["head_branch"], target["head_sha"])
    own = api("actions/runs/" + os.environ["GITHUB_RUN_ID"])
    assert own["head_sha"] == own_head and own["head_branch"] == branch
    own_workflow = api("actions/workflows/" + str(own["workflow_id"]))
    assert own_workflow["path"] == workflow_path
    report["ownObservedDisabled"] = disabled(own_workflow)["state"]
    report["ownWorkflow"] = own["workflow_id"]
    report["ownRun"] = own["id"]
    report["ownBranch"] = remove_exact(branch, own_head)
    after = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], capture_output=True, timeout=5)
    assert after.returncode == 0 and after.stdout == baseline.stdout
    report["sourceUnchanged"] = True
    report["nativeRerun"] = False
    report["status"] = "passed"
except BaseException:
    report["errors"].append(traceback.format_exc())
finally:
    raw = json.dumps(report, separators=(",", ":")).encode()
    assert len(raw) <= 8 * 1024 ** 2
    print("FRAMELET_COMPOSITION_RETIREMENT_CLOSEOUT=" + base64.b64encode(gzip.compress(raw, mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
