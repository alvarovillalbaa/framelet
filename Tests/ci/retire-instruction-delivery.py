"""Retire only this exact uploaded pixel-check control, including on failure."""
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import traceback

repository = "alvarovillalbaa/framelet"
branch = "qa/framelet-instruction-delivery-20261112-2"
path = ".github/workflows/framelet-instruction-delivery-20261112-2.yml"
assert os.environ["GITHUB_REPOSITORY"] == repository and os.environ["GITHUB_REF"] == "refs/heads/" + branch
head = os.environ["GITHUB_SHA"]
assert re.fullmatch(r"[0-9a-f]{40}", head)
deadline = time.monotonic() + 90
report = {"kind": "framelet-instruction-delivery-control-retirement", "status": "failed", "requests": [], "errors": []}
sha = lambda data: hashlib.sha256(data).hexdigest()


def api(route, method="GET", expected=200):
    assert time.monotonic() + 1 < deadline and len(report["requests"]) < 24
    timed_out = False
    try:
        command = subprocess.run(["gh", "api", "--include", "-H", "Cache-Control: no-cache", "--method", method,
            "repos/" + repository + "/" + route], capture_output=True, timeout=min(10, deadline - time.monotonic()))
        stdout, stderr, exit_code = command.stdout, command.stderr, command.returncode
    except subprocess.TimeoutExpired as error:
        stdout, stderr, exit_code, timed_out = error.stdout or b"", error.stderr or b"", None, True
    out, err = stdout[:2 * 1024 ** 2], stderr[:65536]
    complete = not timed_out and len(out) == len(stdout) and len(err) == len(stderr)
    header, _, body = out.replace(b"\r\n", b"\n").partition(b"\n\n")
    match = re.match(rb"HTTP/\S+ (\d{3})", header)
    status = int(match[1]) if match else None
    report["requests"].append({"route": route, "method": method, "status": status, "exitCode": exit_code,
        "complete": complete, "timedOut": timed_out,
        "stdoutBytes": len(out), "stdoutSHA256": sha(out), "observedStdoutBytes": len(stdout), "observedStdoutSHA256": sha(stdout),
        "stdoutGzipBase64": base64.b64encode(gzip.compress(out, mtime=0)).decode(),
        "stderrBytes": len(err), "stderrSHA256": sha(err), "observedStderrBytes": len(stderr), "observedStderrSHA256": sha(stderr),
        "stderrGzipBase64": base64.b64encode(gzip.compress(err, mtime=0)).decode()})
    assert complete and exit_code == 0 and status == expected, "Rejected/incomplete request; no retry"
    return json.loads(body) if body.strip() else None


admitted = False
try:
    run = api("actions/runs/" + os.environ["GITHUB_RUN_ID"])
    workflow = api("actions/workflows/" + str(run["workflow_id"]))
    assert run["head_sha"] == head and run["head_branch"] == branch and workflow["path"] == path
    assert workflow["state"] in ("active", "disabled_manually")
    report.update(run=run["id"], workflow=workflow["id"], branch=branch, path=path)
    admitted = True
    report["uploadedEvidenceRemoved"] = False
    artifact_id = os.environ.get("FRAMELET_ARTIFACT_ID", "")
    if artifact_id:
        assert artifact_id.isdigit()
        artifact = None
        for index in range(6):
            artifacts = api("actions/runs/" + str(run["id"]) + "/artifacts")["artifacts"]
            assert len(artifacts) <= 1
            if artifacts:
                assert str(artifacts[0]["id"]) == artifact_id
                artifact = artifacts[0]; break
            if index < 5: time.sleep(2)
        assert artifact is not None, "Artifact not visible in bounded successful collection reads"
        assert not artifact["expired"] and 0 < artifact["size_in_bytes"] <= 64 * 1024 ** 2
        assert artifact["workflow_run"]["id"] == run["id"] and artifact["workflow_run"]["head_sha"] == head
        assert artifact["digest"] == "sha256:" + os.environ["FRAMELET_ARTIFACT_DIGEST"]
        parent = Path(os.environ["RUNNER_TEMP"]).resolve()
        folder = parent / ("framelet-instruction-delivery-evidence-" + os.environ["GITHUB_RUN_ID"])
        assert folder.parent == parent and folder.is_dir() and not folder.is_symlink() and folder.stat().st_uid == os.getuid()
        receipt = folder / "receipt.json"
        assert receipt.is_file() and not receipt.is_symlink() and receipt.stat().st_size <= 48 * 1024 ** 2
        assert json.loads(receipt.read_bytes())["source"] == os.environ["FRAMELET_SOURCE_COMMIT"]
        shutil.rmtree(folder); assert not folder.exists()
        report["uploadedEvidenceRemoved"] = True
        report["artifactId"] = artifact_id
except BaseException:
    report["errors"].append(traceback.format_exc())
finally:
    try:
        assert admitted, "No admitted exact control; do not mutate"
        if workflow["state"] == "active":
            api("actions/workflows/" + str(workflow["id"]) + "/disable", "PUT", 204)
        for index in range(6):
            state = api("actions/workflows/" + str(workflow["id"]))["state"]
            if state == "disabled_manually": break
            assert state == "active", "Unexpected workflow state"
            if index < 5: time.sleep(2)
        assert state == "disabled_manually"
        report["observedDisabled"] = state
        assert api("git/ref/heads/" + branch)["object"]["sha"] == head
        api("git/refs/heads/" + branch, "DELETE", 204)
        assert not api("git/matching-refs/heads/" + branch)
        report.update(deletedHead=head, exactRefAbsent=True)
    except BaseException:
        report["errors"].append(traceback.format_exc())
    if admitted and report.get("exactRefAbsent") and not report["errors"]:
        report["status"] = "passed"
    raw = json.dumps(report, separators=(",", ":")).encode()
    assert len(raw) <= 8 * 1024 ** 2
    print("FRAMELET_INSTRUCTION_DELIVERY_RETIREMENT=" + base64.b64encode(gzip.compress(raw, mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
