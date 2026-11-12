"""Publish only the three already-qualified assets; no build, app or test."""
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
import urllib.request

repo = "alvarovillalbaa/framelet"
branch = "qa/framelet-window-publish-20261112-1"
workflow_path = ".github/workflows/framelet-window-publish-20261112-1.yml"
tag = "v0.1.2-preview.1"
package_source = "5d6e55447e372e5b9ea510ebebf85738f6e6bc24"
receipt_path = "docs/results/2026/11-12/window-preview-attempt-1.json"
receipt_sha256 = "61e2cef60c9f644a0b48249c05a79eec2efa05df522db7eff4f45f604f835a01"
assert os.environ["GITHUB_REPOSITORY"] == repo and os.environ["GITHUB_REF"] == "refs/heads/" + branch
sha = lambda data: hashlib.sha256(data).hexdigest()
requests = []


def api(route, method="GET", expected=200, payload=None):
    args = ["gh", "api", "--include", "--method", method, "repos/" + repo + "/" + route]
    if payload is not None: args.extend(["--input", "-"])
    command = subprocess.run(args, input=json.dumps(payload).encode() if payload is not None else None,
        capture_output=True, timeout=30)
    assert len(command.stdout) <= 2 * 1024 ** 2 and len(command.stderr) <= 65536
    header, _, body = command.stdout.replace(b"\r\n", b"\n").partition(b"\n\n")
    match = re.match(rb"HTTP/\S+ (\d{3})", header)
    status = int(match[1]) if match else None
    requests.append({"method": method, "route": route, "status": status, "sha256": sha(command.stdout)})
    assert command.returncode == 0 and status == expected, "API request rejected; no retry"
    return json.loads(body) if body.strip() else None


def old_assets():
    release = api("releases/438167998")
    assert release["tag_name"] == "v0.1.0-preview.1" and not release["draft"]
    assert api("git/ref/tags/v0.1.0-preview.1")["object"]["sha"] == "05074098c1053a1d47e69ee9117b8338e1bcc8c2"
    pins = {723581535: (1157438, "c84865b23c93113114f44d7cbff17f19ca661905f2a1ca0f8f18a2b02ef1e76a"),
        723581604: (101, "1435dfc7a21632d75242cdc0a87c0ed226cafb40e0c0ac2907ad824e94fc6ffa"),
        723581621: (1735, "3f899233af08cb19567100fa9a0cd5c47d7d652bf8f8f3ac957771a6b29750f2")}
    assets = release["assets"]
    assert {a["id"] for a in assets} == set(pins)
    for asset in assets:
        size, digest = pins[asset["id"]]
        assert asset["size"] == size and asset["digest"] == "sha256:" + digest
    evidence = api("releases/442693072")
    assert evidence["tag_name"] == "framelet-ui-evidence-20261112-attempt-5" and not evidence["draft"]
    assert api("git/ref/tags/framelet-ui-evidence-20261112-attempt-5")["object"]["sha"] == "a65b02697adba86b49ea730dd02e7eec0b281110"
    assert len(evidence["assets"]) == 1
    asset = evidence["assets"][0]
    assert asset["id"] == 738757493 and asset["size"] == 98057941
    assert asset["digest"] == "sha256:c9e8a9831198623d7673ed096dc59c02eeae48859101211c0d1a928305d33496"
    previous = api("releases/442765166")
    assert previous["tag_name"] == "v0.1.1-preview.1" and not previous["draft"]
    assert api("git/ref/tags/v0.1.1-preview.1")["object"]["sha"] == "618cabda9b08b04604dbb7992e8c4f73ff9606a8"
    previous_pins = {738972227: (1159292, "0a02be066db9936c35decab2b32e4892cbf1c75b97ed3d2188c0abc420a78fce"),
        738972230: (101, "f7631379c8b09a575a5016967254336237cc85c18a6e9716cbb4be378edd57dc"),
        738972234: (2617, "a05a21480e2df7852911a09b16f6f4fc378f1d4901de2c4022eff164e6158bd5")}
    assert {a["id"] for a in previous["assets"]} == set(previous_pins)
    for a in previous["assets"]:
        size, digest = previous_pins[a["id"]]
        assert a["size"] == size and a["digest"] == "sha256:" + digest
    return [{"id": a["id"], "size": a["size"], "digest": a["digest"]} for a in [*assets, asset, *previous["assets"]]]


report = {"schemaVersion": 1, "kind": "framelet-preview-publication", "status": "failed",
    "packageSource": package_source, "applicationOrTestsExecuted": False, "requests": requests}
root = None
try:
    raw = Path(receipt_path).read_bytes()
    assert sha(raw) == receipt_sha256
    receipt = json.loads(raw)
    assert receipt["status"] == "passed" and receipt["sourceCommit"] == package_source
    assert receipt["cleanup"]["verified"] and receipt["cleanup"]["rootAbsent"]
    assert receipt["nativeAcceptance"]["caseId"] == "FUI02" and receipt["nativeAcceptance"]["fixtureReadOnlyUnchanged"]
    assert not receipt["ownedSignals"]
    assert receipt["testsExecuted"] is False and receipt["applicationLaunched"] is False
    names = {"Framelet-0.1.2-macos-universal.zip", "Framelet-0.1.2-macos-universal.zip.sha256", "Framelet-preview-manifest.json"}
    assert set(receipt["retainedOriginals"]) == names
    report["oldAssetsBefore"] = old_assets()
    assert not api("git/matching-refs/tags/" + tag)
    parent = Path(os.environ["RUNNER_TEMP"]).resolve()
    root = Path(tempfile.mkdtemp(prefix="framelet-publish-", dir=parent))
    identity = (root.stat().st_dev, root.stat().st_ino)
    files = {}
    for name, item in receipt["retainedOriginals"].items():
        data = gzip.decompress(base64.b64decode(item["gzipBase64"], validate=True))
        assert 0 < len(data) == item["bytes"] <= 8 * 1024 ** 2 and sha(data) == item["sha256"]
        path = root / name
        with path.open("xb") as stream: stream.write(data)
        files[name] = {"bytes": len(data), "sha256": sha(data)}
    report["assets"] = files
    release = api("releases", "POST", 201, payload={"tag_name": tag, "target_commitish": package_source,
        "name": "Framelet 0.1.2 developer preview",
        "body": "Local macOS recorder/editor preview with display-aware initial window placement. Focused native first-launch/relaunch/additional-window qualification passed on an arm64/debug VM; earlier authored-media edit/export evidence keeps its original source. Both actual Release architectures, signatures and fresh ZIP extraction passed separately. Requires macOS 15+. Ad-hoc signed; no Developer ID/notarization. Actual capture, camera/audio timing, physical multi-monitor/device and downloaded-app trust acceptance remain open. See distribution notes and the exact source/toolchain manifest. No cloud account or paid service required.",
        "draft": True, "prerelease": True, "make_latest": "false"})
    report["releaseId"] = release["id"]
    command = subprocess.run(["gh", "release", "upload", tag, *[str(root / name) for name in sorted(names)],
        "--repo", repo], capture_output=True, timeout=90)
    assert command.returncode == 0 and len(command.stdout) <= 65536 and len(command.stderr) <= 65536
    assets = api("releases/" + str(release["id"]) + "/assets")
    assert {a["name"] for a in assets} == names and len(assets) == 3
    for asset in assets:
        item = files[asset["name"]]
        assert asset["size"] == item["bytes"] and asset["digest"] == "sha256:" + item["sha256"]
    published = api("releases/" + str(release["id"]), "PATCH", payload={"draft": False, "make_latest": "false"})
    assert not published["draft"] and published["prerelease"] and published["tag_name"] == tag
    assert api("git/ref/tags/" + tag)["object"]["sha"] == package_source
    # Anonymous requests have no GitHub token, cookies, or Authorization header.
    fresh = api("releases/" + str(release["id"]))
    downloads = []
    for asset in fresh["assets"]:
        url = asset["browser_download_url"]
        assert url == "https://github.com/" + repo + "/releases/download/" + tag + "/" + asset["name"]
        request = urllib.request.Request(url, headers={"User-Agent": "Framelet-preview-publication"})
        with urllib.request.urlopen(request, timeout=30) as response:
            data = response.read(8 * 1024 ** 2 + 1)
            assert response.status == 200
        item = files[asset["name"]]
        assert len(data) == item["bytes"] and sha(data) == item["sha256"]
        downloads.append({"name": asset["name"], "url": url, "status": 200, "bytes": len(data), "sha256": sha(data), "authenticated": False})
    report.update(tag=tag, url=fresh["html_url"], serverAssets=fresh["assets"], anonymousDownloads=downloads)
    report["oldAssetsAfter"] = old_assets()
    assert report["oldAssetsAfter"] == report["oldAssetsBefore"]
    report["status"] = "passed"
except BaseException as error:
    report["error"] = type(error).__name__ + ": " + str(error)
finally:
    try:
        if root is not None:
            assert not root.is_symlink() and root.parent == parent
            assert (root.stat().st_dev, root.stat().st_ino) == identity
            assert {p.name for p in root.iterdir()} <= names
            for path in root.iterdir():
                assert path.is_file() and not path.is_symlink()
                assert sha(path.read_bytes()) == files[path.name]["sha256"]
            shutil.rmtree(root); assert not root.exists()
        report["ownedRootAbsent"] = True
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
    except BaseException as error:
        report.update(status="failed", cleanupError=type(error).__name__ + ": " + str(error))
    print("FRAMELET_WINDOW_PUBLICATION=" + base64.b64encode(gzip.compress(json.dumps(report, separators=(",", ":")).encode(), mtime=0)).decode(), flush=True)
    raise SystemExit(0 if report["status"] == "passed" else 1)
