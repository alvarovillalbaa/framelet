"""Diagnose/retire only the terminal, never-allocated FUI03A candidate and self."""
import base64
import gzip
import hashlib
import json
import os
import re
import subprocess

repo = "alvarovillalbaa/framelet"
branch = "qa/framelet-picker-allocation-20261112"
path = ".github/workflows/framelet-picker-allocation-20261112.yml"
old_branch = "qa/framelet-picker-20261112-1"
old_path = ".github/workflows/framelet-picker-20261112-1.yml"
old_head = "28ac1d1bd33ec7f1e23038cd17c1d276523ff4ce"
assert os.environ["GITHUB_REPOSITORY"] == repo and os.environ["GITHUB_REF"] == "refs/heads/" + branch
requests = []


def api(route, method="GET", expected=200):
    response = subprocess.run(["gh", "api", "--include", "--method", method, "repos/" + repo + "/" + route],
        capture_output=True, timeout=15)
    assert len(response.stdout) <= 2 * 1024 ** 2 and len(response.stderr) <= 65536
    header, _, body = response.stdout.replace(b"\r\n", b"\n").partition(b"\n\n")
    match = re.match(rb"HTTP/\S+ (\d{3})", header)
    status = int(match[1]) if match else None
    requests.append({"method": method, "route": route, "status": status,
        "sha256": hashlib.sha256(response.stdout).hexdigest()})
    assert response.returncode == 0 and status == expected, "request rejected; no retry"
    return json.loads(body) if body.strip() else None


report = {"schemaVersion": 1, "kind": "framelet-unallocated-picker-retirement", "status": "failed",
    "nativeRun": 43211146295, "job": 131158773329, "applicationBuildOrTestsExecuted": False,
    "requests": requests}
try:
    old = api("actions/runs/43211146295")
    assert old["head_sha"] == old_head and old["head_branch"] == old_branch
    assert old["status"] == "completed" and old["conclusion"] in ("failure", "cancelled") and old["run_attempt"] == 1
    job = api("actions/jobs/131158773329")
    assert job["run_id"] == old["id"] and job["status"] == "completed"
    assert job["conclusion"] == "cancelled" and job["steps"] == [] and job["runner_id"] == 0
    report["nativeRunMetadata"] = old
    report["unallocatedJobMetadata"] = job
    prefix = "https://api.github.com/repos/" + repo + "/"
    check_route = job["check_run_url"].removeprefix(prefix)
    assert re.fullmatch(r"check-runs/[0-9]+", check_route)
    check = api(check_route)
    report["checkOutput"] = check["output"]
    report["annotations"] = api(check_route + "/annotations?per_page=100")
    workflow = api("actions/workflows/" + str(old["workflow_id"]))
    assert workflow["path"] == old_path and workflow["state"] == "active"
    assert api("git/ref/heads/" + old_branch)["object"]["sha"] == old_head
    api("actions/workflows/" + str(workflow["id"]) + "/disable", "PUT", 204)
    assert api("actions/workflows/" + str(workflow["id"]))["state"] == "disabled_manually"
    assert api("git/ref/heads/" + old_branch)["object"]["sha"] == old_head
    api("git/refs/heads/" + old_branch, "DELETE", 204)
    assert not api("git/matching-refs/heads/" + old_branch)
    report["unallocatedControlRetirement"] = {"workflow": workflow["id"], "disabledState": "disabled_manually",
        "branch": old_branch, "deletedHead": old_head, "exactRefAbsent": True,
        "executorNeverAcquired": True, "executorResourcesCreated": False}
    report["status"] = "passed"
except BaseException as error:
    report["error"] = type(error).__name__ + ": " + str(error)
finally:
    try:
        own = api("actions/runs/" + os.environ["GITHUB_RUN_ID"])
        workflow = api("actions/workflows/" + str(own["workflow_id"]))
        assert own["head_sha"] == os.environ["GITHUB_SHA"] and own["head_branch"] == branch and workflow["path"] == path
        api("actions/workflows/" + str(workflow["id"]) + "/disable", "PUT", 204)
        assert api("actions/workflows/" + str(workflow["id"]))["state"] == "disabled_manually"
        assert api("git/ref/heads/" + branch)["object"]["sha"] == own["head_sha"]
        api("git/refs/heads/" + branch, "DELETE", 204)
        assert not api("git/matching-refs/heads/" + branch)
        report["controlRetirement"] = {"workflow": workflow["id"], "disabledState": "disabled_manually",
            "deletedHead": own["head_sha"], "branch": branch, "exactRefAbsent": True}
    except BaseException as error:
        report.update(status="failed", retirementError=type(error).__name__ + ": " + str(error))
    print("FRAMELET_PICKER_ALLOCATION=" + base64.b64encode(gzip.compress(json.dumps(report,
        separators=(",", ":")).encode(), mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
