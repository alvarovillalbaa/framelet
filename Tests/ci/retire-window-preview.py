"""Retire the one preview-refresh control after its bounded invocation."""
import hashlib
import json
import os
import re
import subprocess

repo = "alvarovillalbaa/framelet"
branch = "qa/framelet-window-preview-20261112-1"
path = ".github/workflows/framelet-window-preview-20261112-1.yml"
assert os.environ["GITHUB_REPOSITORY"] == repo and os.environ["GITHUB_REF"] == "refs/heads/" + branch
head = os.environ["GITHUB_SHA"]
assert re.fullmatch(r"[0-9a-f]{40}", head)
requests = []


def api(route, method="GET", expected=200):
    command = subprocess.run(["gh", "api", "--include", "--method", method, "repos/" + repo + "/" + route],
        capture_output=True, timeout=20)
    assert len(command.stdout) <= 2 * 1024 ** 2 and len(command.stderr) <= 65536
    header, _, body = command.stdout.replace(b"\r\n", b"\n").partition(b"\n\n")
    match = re.match(rb"HTTP/\S+ (\d{3})", header)
    status = int(match[1]) if match else None
    requests.append({"route": route, "method": method, "status": status,
        "responseSHA256": hashlib.sha256(command.stdout).hexdigest()})
    assert command.returncode == 0 and status == expected, "retirement request rejected; no retry"
    return json.loads(body) if body.strip() else None


run = api("actions/runs/" + os.environ["GITHUB_RUN_ID"])
workflow = api("actions/workflows/" + str(run["workflow_id"]))
assert run["head_sha"] == head and run["head_branch"] == branch and workflow["path"] == path and workflow["state"] == "active"
api("actions/workflows/" + str(workflow["id"]) + "/disable", "PUT", 204)
assert api("actions/workflows/" + str(workflow["id"]))["state"] == "disabled_manually"
assert api("git/ref/heads/" + branch)["object"]["sha"] == head
api("git/refs/heads/" + branch, "DELETE", 204)
assert not api("git/matching-refs/heads/" + branch)
print("FRAMELET_WINDOW_PREVIEW_RETIREMENT=" + json.dumps({"status": "passed", "run": run["id"], "workflow": workflow["id"],
    "path": path, "disabledState": "disabled_manually", "branch": branch, "deletedHead": head,
    "exactRefAbsent": True,
    "requests": requests}, separators=(",", ":")), flush=True)
