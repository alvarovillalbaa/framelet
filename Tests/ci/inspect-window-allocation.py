"""Read the cancelled executor's public check diagnostics; no app/build/test."""
import base64
import gzip
import hashlib
import json
import os
import re
import subprocess

repo = "alvarovillalbaa/framelet"
branch = "qa/framelet-window-allocation-20261112"
path = ".github/workflows/framelet-window-allocation-20261112.yml"
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
    assert response.returncode == 0 and status == expected, "read rejected; no retry"
    return json.loads(body) if body.strip() else None


report = {"schemaVersion": 1, "kind": "framelet-window-allocation-diagnostic", "status": "failed",
    "nativeRun": 43202901167, "cancelledJob": 131130604433,
    "applicationBuildOrTestsExecuted": False, "requests": requests}
try:
    old = api("actions/jobs/131130604433")
    assert old["run_id"] == 43202901167 and old["conclusion"] == "cancelled" and old["steps"] == [] and old["runner_id"] == 0
    report["cancelledJobMetadata"] = old
    check = api("check-runs/131130604433")
    report["checkOutput"] = check["output"]
    report["annotations"] = api("check-runs/131130604433/annotations?per_page=100")
    current = api("actions/runs/43202901167")
    assert current["head_sha"] == "1b631c87cb4da85fffbfb2ef0166cc84596452b5"
    report["currentNativeRun"] = {k: current[k] for k in ("id", "status", "conclusion", "run_attempt", "head_sha")}
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
    print("FRAMELET_ALLOCATION_DIAGNOSTIC=" + base64.b64encode(gzip.compress(json.dumps(report,
        separators=(",", ":")).encode(), mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
