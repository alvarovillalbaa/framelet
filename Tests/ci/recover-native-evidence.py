"""Read one retained artifact; no application, build, test or permission change."""
import base64
import gzip
import hashlib
import io
import json
import os
from pathlib import PurePosixPath
import re
import stat
import subprocess
import tempfile
import zipfile

repo = "alvarovillalbaa/framelet"
branch = "qa/framelet-ui-evidence-20261112"
workflow_path = ".github/workflows/framelet-ui-evidence-20261112.yml"
artifact_id = 13927483704
assert os.environ["GITHUB_REPOSITORY"] == repo and os.environ["GITHUB_REF"] == "refs/heads/" + branch
sha = lambda value: hashlib.sha256(value).hexdigest()
requests = []


def api(route, method="GET", expected=200, binary=False, payload=None):
    args = ["gh", "api", "--method", method, "repos/" + repo + "/" + route]
    if not binary: args.append("--include")
    if payload is not None: args.extend(["--input", "-"])
    value = subprocess.run(args, input=json.dumps(payload).encode() if payload is not None else None,
        capture_output=True, timeout=90 if binary else 30)
    assert len(value.stderr) <= 65536
    if binary:
        assert value.returncode == 0 and len(value.stdout) <= 128 * 1024 ** 2
        return value.stdout
    assert len(value.stdout) <= 2 * 1024 ** 2
    header, _, body = value.stdout.replace(b"\r\n", b"\n").partition(b"\n\n")
    match = re.match(rb"HTTP/\S+ (\d{3})", header)
    status = int(match[1]) if match else None
    requests.append({"method": method, "route": route, "status": status, "sha256": sha(value.stdout)})
    assert value.returncode == 0 and status == expected
    return json.loads(body) if body.strip() else None


report = {"schemaVersion": 1, "kind": "framelet-evidence-recovery", "status": "failed", "sourceRun": 43184217179,
    "sourceHead": "d899e6ba0708ff016030e9fe232205a2c30c2f61", "artifactId": artifact_id,
    "applicationOrTestsExecuted": False, "requests": requests}
try:
    artifact = api("actions/artifacts/" + str(artifact_id))
    assert not artifact["expired"] and artifact["size_in_bytes"] == 98057941
    assert artifact["workflow_run"]["id"] == report["sourceRun"] and artifact["workflow_run"]["head_sha"] == report["sourceHead"]
    data = api("actions/artifacts/" + str(artifact_id) + "/zip", binary=True)
    assert artifact["digest"] == "sha256:" + sha(data)
    report["archive"] = {"bytes": len(data), "sha256": sha(data), "serverDigest": artifact["digest"]}
    # Preserve the entire original, including automatic native video, without
    # downloading 98 MB onto the storage-blocked local machine or bloating Git.
    tag = "framelet-ui-evidence-20261112-attempt-5"
    assert not api("git/matching-refs/tags/" + tag)
    release = api("releases", "POST", 201, payload={"tag_name": tag,
        "target_commitish": "a65b02697adba86b49ea730dd02e7eec0b281110",
        "name": "Native UI failure evidence — 12 November 2026",
        "body": "Evidence only, not an application download. Original failed FUI01 run 43184217179, artifact 13927483704. The case remains failed. Contains generated CI media, native screenshots/recording, test results and complete command streams. Archive SHA-256: " + sha(data),
        "draft": True, "prerelease": True, "make_latest": "false"})
    with tempfile.TemporaryDirectory(prefix="framelet-evidence-", dir=os.environ["RUNNER_TEMP"]) as folder:
        from pathlib import Path
        archive_path = Path(folder) / "framelet-native-ui-attempt-5.zip"
        archive_path.write_bytes(data)
        upload = subprocess.run(["gh", "release", "upload", tag, str(archive_path), "--repo", repo], capture_output=True, timeout=90)
        assert upload.returncode == 0 and len(upload.stdout) <= 65536 and len(upload.stderr) <= 65536
        assets = api("releases/" + str(release["id"]) + "/assets")
        assert len(assets) == 1 and assets[0]["name"] == archive_path.name
        assert assets[0]["size"] == len(data) and assets[0]["digest"] == "sha256:" + sha(data)
        published = api("releases/" + str(release["id"]), "PATCH", payload={"draft": False, "make_latest": "false"})
        assert published["draft"] is False and published["prerelease"] is True
        assert api("git/ref/tags/" + tag)["object"]["sha"] == "a65b02697adba86b49ea730dd02e7eec0b281110"
        report["archiveCarrier"] = {"releaseId": release["id"], "tag": tag, "url": published["html_url"],
            "asset": assets[0], "draft": False, "prerelease": True}
    entries = []
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        infos = archive.infolist()
        assert len(infos) <= 8192 and sum(info.file_size for info in infos) <= 128 * 1024 ** 2
        assert len({info.filename for info in infos}) == len(infos)
        for info in infos:
            path = PurePosixPath(info.filename)
            assert not path.is_absolute() and ".." not in path.parts and "\\" not in info.filename
            assert stat.S_IFMT(info.external_attr >> 16) != stat.S_IFLNK
            with archive.open(info) as stream:
                digest = hashlib.sha256()
                for chunk in iter(lambda: stream.read(65536), b""): digest.update(chunk)
            entries.append({"path": info.filename, "bytes": info.file_size, "sha256": digest.hexdigest()})
        report["members"] = entries
        manifest = json.loads(archive.read("attachments/manifest.json"))
        recovered = []
        total = 0
        for case in manifest:
            assert case["testIdentifier"] == "FrameletAcceptance/testFUI01EditReopenAndExportNativeRecording()"
            for item in case["attachments"]:
                filename = item["exportedFileName"]
                assert PurePosixPath(filename).name == filename and filename not in (".", "..")
                name = item["suggestedHumanReadableName"]
                canonical = re.fullmatch(r"(01-library-preview|02-edited-clips|03-native-export|04-reopened-library|diagnostic-final|ui-observations)_[0-9]+_([A-F0-9-]{36})\.(png|json|accessibility)", name)
                if not canonical and not name.startswith(("App UI hierarchy", "UI Snapshot", "Complete Issue Description")):
                    continue
                raw = archive.read("attachments/" + filename); total += len(raw)
                assert len(raw) <= 2 * 1024 ** 2 and total <= 8 * 1024 ** 2
                recovered.append({"name": name, "file": filename, "canonicalName": canonical[1] + "." + canonical[3] if canonical else None,
                    "bytes": len(raw), "sha256": sha(raw), "gzipBase64": base64.b64encode(gzip.compress(raw, mtime=0)).decode()})
        report["attachments"] = recovered
        assert any(row["canonicalName"] == "02-edited-clips.png" for row in recovered)
    report["status"] = "passed"
except BaseException as error:
    report["error"] = type(error).__name__ + ": " + str(error)
finally:
    own = api("actions/runs/" + os.environ["GITHUB_RUN_ID"])
    workflow = api("actions/workflows/" + str(own["workflow_id"]))
    assert own["head_sha"] == os.environ["GITHUB_SHA"] and own["head_branch"] == branch and workflow["path"] == workflow_path
    api("actions/workflows/" + str(workflow["id"]) + "/disable", "PUT", 204)
    assert api("actions/workflows/" + str(workflow["id"]))["state"] == "disabled_manually"
    assert api("git/ref/heads/" + branch)["object"]["sha"] == own["head_sha"]
    api("git/refs/heads/" + branch, "DELETE", 204)
    assert not api("git/matching-refs/heads/" + branch)
    report["controlRetirement"] = {"workflow": workflow["id"], "disabledState": "disabled_manually", "branch": branch,
        "deletedHead": own["head_sha"], "exactRefAbsent": True}
    print("FRAMELET_EVIDENCE_RECOVERY=" + base64.b64encode(gzip.compress(json.dumps(report, separators=(",", ":")).encode(), mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
