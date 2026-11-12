"""Retire the exact temporary UI control; preserve evidence unless uploaded."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

repo = "alvarovillalbaa/framelet"
branch = "qa/framelet-composition-probe-20261112-1"
path = ".github/workflows/framelet-composition-probe-20261112-1.yml"
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
artifact_id = os.environ.get("FRAMELET_ARTIFACT_ID", "")
evidence_removed = False
if artifact_id:
    assert artifact_id.isdigit()
    artifact = api("actions/artifacts/" + artifact_id)
    assert not artifact["expired"] and 0 < artifact["size_in_bytes"] <= 256 * 1024 ** 2
    assert artifact["workflow_run"]["id"] == run["id"] and artifact["workflow_run"]["head_sha"] == head
    assert artifact["digest"] == "sha256:" + os.environ["FRAMELET_ARTIFACT_DIGEST"]
    parent = Path(os.environ["RUNNER_TEMP"]).resolve()
    folder = parent / ("framelet-composition-probe-evidence-" + os.environ["GITHUB_RUN_ID"])
    assert folder.parent == parent and folder.is_dir() and not folder.is_symlink()
    assert folder.stat().st_uid == os.getuid() and (folder / "receipt.json").is_file()
    shutil.rmtree(folder); assert not folder.exists()
    evidence_removed = True
api("actions/workflows/" + str(workflow["id"]) + "/disable", "PUT", 204)
assert api("actions/workflows/" + str(workflow["id"]))["state"] == "disabled_manually"
assert api("git/ref/heads/" + branch)["object"]["sha"] == head
api("git/refs/heads/" + branch, "DELETE", 204)
assert not api("git/matching-refs/heads/" + branch)
print("FRAMELET_COMPOSITION_PROBE_RETIREMENT=" + json.dumps({"status": "passed", "run": run["id"], "workflow": workflow["id"],
    "path": path, "disabledState": "disabled_manually", "branch": branch, "deletedHead": head,
    "exactRefAbsent": True, "uploadedEvidenceRemoved": evidence_removed, "artifactId": artifact_id,
    "requests": requests}, separators=(",", ":")), flush=True)
