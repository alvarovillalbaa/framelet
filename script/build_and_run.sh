#!/usr/bin/env bash
set -euo pipefail

FRAMELET_MODE="${1:-run}"
case "$FRAMELET_MODE" in
  run|--build-only|--build-preview|--debug|--logs|--telemetry|--verify) ;;
  *) echo "usage: $0 [--build-only|--build-preview|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
if [[ "$FRAMELET_MODE" == --build-preview && "$#" != 1 ]]; then
  echo "--build-preview accepts no other arguments." >&2
  exit 2
fi
FRAMELET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$FRAMELET_ROOT"
FRAMELET_DIST="$FRAMELET_ROOT/dist"
FRAMELET_APP="$FRAMELET_DIST/Framelet.app"
FRAMELET_PREVIEW_NAME="Framelet-0.1.5-macos-universal.zip"
FRAMELET_PREVIEW_COMPLETE=0
if [[ "$FRAMELET_MODE" == --build-preview ]]; then
  FRAMELET_BUILD_FLAGS=(--configuration release --build-system native --disable-local-rpath)
  if [[ -n "${FRAMELET_SWIFTPM_CACHE:-}" ]]; then
    if [[ "$FRAMELET_SWIFTPM_CACHE" != /* || ! -d "$FRAMELET_SWIFTPM_CACHE" || -L "$FRAMELET_SWIFTPM_CACHE" ]]; then
      echo "FRAMELET_SWIFTPM_CACHE must be an existing absolute directory, not a symlink." >&2
      exit 1
    fi
    FRAMELET_BUILD_FLAGS+=(--cache-path "$FRAMELET_SWIFTPM_CACHE")
  fi
  command -v python3 >/dev/null || { echo "Preview packaging requires Python 3's standard library." >&2; exit 1; }
  if [[ -L "$FRAMELET_DIST" || ( -e "$FRAMELET_DIST" && ! -d "$FRAMELET_DIST" ) ]]; then
    echo "Refusing an unsafe preview output directory." >&2
    exit 1
  fi
  for FRAMELET_OUTPUT in "$FRAMELET_DIST/$FRAMELET_PREVIEW_NAME" "$FRAMELET_DIST/$FRAMELET_PREVIEW_NAME.sha256"; do
    if [[ -e "$FRAMELET_OUTPUT" || -L "$FRAMELET_OUTPUT" ]]; then
      echo "Preview output already exists; nothing was replaced: $FRAMELET_OUTPUT" >&2
      exit 1
    fi
  done
fi
if [[ -f "$HOME/.codex/storage-policy.md" ]]; then
  FRAMELET_GUARD="$HOME/Library/Application Support/LocalStorageGuard/storage_guard.py"
  if [[ ! -f "$FRAMELET_GUARD" ]]; then
    echo "The workspace storage policy exists but its guard is unavailable." >&2
    exit 1
  fi
  python3 "$FRAMELET_GUARD" preflight --need-gib 4
fi

# Ask the app to quit through its termination guard. Never force-kill a recording.
if pgrep -x Framelet >/dev/null; then
  if [[ "$FRAMELET_MODE" == --build-only || "$FRAMELET_MODE" == --build-preview ]]; then
    echo "Close Framelet before replacing its app bundle. An active recording has been left alone." >&2
    exit 1
  fi
  /usr/bin/osascript -e 'tell application id "com.alvarovillalbaa.Framelet" to quit'
  for FRAMELET_ATTEMPT in {1..20}; do
    pgrep -x Framelet >/dev/null || break
    sleep 0.25
  done
  if pgrep -x Framelet >/dev/null; then
    echo "Framelet stayed open. Finish your recording and quit before rebuilding." >&2
    exit 1
  fi
fi

if [[ "$FRAMELET_MODE" == --build-preview ]]; then
  swift build --product Framelet "${FRAMELET_BUILD_FLAGS[@]}" --arch arm64 --scratch-path "$FRAMELET_ROOT/.build/preview-arm64"
  FRAMELET_ARM64_BINARY="$(swift build "${FRAMELET_BUILD_FLAGS[@]}" --arch arm64 --scratch-path "$FRAMELET_ROOT/.build/preview-arm64" --show-bin-path)/Framelet"
  swift build --product Framelet "${FRAMELET_BUILD_FLAGS[@]}" --arch x86_64 --scratch-path "$FRAMELET_ROOT/.build/preview-x86_64"
  FRAMELET_X86_64_BINARY="$(swift build "${FRAMELET_BUILD_FLAGS[@]}" --arch x86_64 --scratch-path "$FRAMELET_ROOT/.build/preview-x86_64" --show-bin-path)/Framelet"
else
  swift build --product Framelet
  FRAMELET_BINARY="$(swift build --show-bin-path)/Framelet"
fi
mkdir -p "$FRAMELET_DIST"
if [[ -L "$FRAMELET_DIST" || -L "$FRAMELET_APP" ]]; then
  echo "Refusing a symlinked app output path." >&2
  exit 1
fi
if [[ -e "$FRAMELET_APP" ]]; then
  FRAMELET_OLD_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$FRAMELET_APP/Contents/Info.plist")"
  [[ "$FRAMELET_OLD_ID" == com.alvarovillalbaa.Framelet ]] || { echo "Output belongs to another app." >&2; exit 1; }
fi
FRAMELET_STAGE="$(mktemp -d "$FRAMELET_DIST/.framelet-stage.XXXXXX")"
cleanup_framelet_stage() {
  if [[ "$FRAMELET_MODE" == --build-preview && "$FRAMELET_PREVIEW_COMPLETE" == 0 ]]; then
    python3 - "$FRAMELET_STAGE" "$FRAMELET_DIST" "$FRAMELET_PREVIEW_NAME" <<'PY'
from pathlib import Path
import stat
import sys

stage, output = map(Path, sys.argv[1:3])
for name in (sys.argv[3], sys.argv[3] + ".sha256"):
    source, target = stage / name, output / name
    try:
        left, right = source.lstat(), target.lstat()
    except FileNotFoundError:
        continue
    if (stat.S_ISREG(left.st_mode) and stat.S_ISREG(right.st_mode)
            and (left.st_dev, left.st_ino) == (right.st_dev, right.st_ino)):
        target.unlink()
PY
    if [[ -d "$FRAMELET_STAGE/previous.app" ]]; then
      if [[ ! -e "$FRAMELET_APP" && ! -L "$FRAMELET_APP" ]]; then
        mv -n "$FRAMELET_STAGE/previous.app" "$FRAMELET_APP"
      fi
      if [[ -d "$FRAMELET_STAGE/previous.app" ]]; then
        echo "Previous app preserved for recovery: $FRAMELET_STAGE/previous.app" >&2
        return
      fi
    fi
  fi
  if [[ ! -e "$FRAMELET_APP" && -d "$FRAMELET_STAGE/previous.app" ]]; then
    mv "$FRAMELET_STAGE/previous.app" "$FRAMELET_APP"
  fi
  rm -rf "$FRAMELET_STAGE"
}
trap cleanup_framelet_stage EXIT
mkdir -p "$FRAMELET_STAGE/Framelet.app/Contents/MacOS"
mkdir -p "$FRAMELET_STAGE/Framelet.app/Contents/Resources"
if [[ "$FRAMELET_MODE" == --build-preview ]]; then
  /usr/bin/lipo -create "$FRAMELET_ARM64_BINARY" "$FRAMELET_X86_64_BINARY" -output "$FRAMELET_STAGE/Framelet.app/Contents/MacOS/Framelet"
else
  cp "$FRAMELET_BINARY" "$FRAMELET_STAGE/Framelet.app/Contents/MacOS/Framelet"
fi
cp "$FRAMELET_ROOT/Resources/Info.plist" "$FRAMELET_STAGE/Framelet.app/Contents/Info.plist"
cp "$FRAMELET_ROOT/Resources/AppIcon.icns" "$FRAMELET_STAGE/Framelet.app/Contents/Resources/AppIcon.icns"
chmod +x "$FRAMELET_STAGE/Framelet.app/Contents/MacOS/Framelet"
/usr/bin/plutil -lint "$FRAMELET_STAGE/Framelet.app/Contents/Info.plist"
# Local ad-hoc signing uses no certificate, account, network, or paid enrollment.
/usr/bin/codesign --force --sign - "$FRAMELET_STAGE/Framelet.app"
/usr/bin/codesign --verify --strict "$FRAMELET_STAGE/Framelet.app"
if [[ "$FRAMELET_MODE" == --build-preview ]]; then
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$FRAMELET_STAGE/Framelet.app/Contents/Info.plist")" == 0.1.5 ]] || { echo "Preview archive version does not match its bundle." >&2; exit 1; }
  python3 - "$FRAMELET_STAGE/Framelet.app" <<'PY'
from pathlib import Path
import stat
import sys

app = Path(sys.argv[1])
total = 0
for count, path in enumerate(app.rglob("*"), 1):
    if count > 512:
        raise SystemExit("Preview bundle exceeds 512 entries.")
    mode = path.lstat().st_mode
    if stat.S_ISREG(mode):
        total += path.stat().st_size
    elif not stat.S_ISDIR(mode):
        raise SystemExit("Preview bundle contains a nonregular entry.")
    if total > 32 * 1024 * 1024:
        raise SystemExit("Preview bundle exceeds 32 MiB.")
PY
  /usr/bin/ditto -c -k --rsrc --extattr --sequesterRsrc --keepParent "$FRAMELET_STAGE/Framelet.app" "$FRAMELET_STAGE/$FRAMELET_PREVIEW_NAME"
  python3 - "$FRAMELET_STAGE" "$FRAMELET_DIST" "$FRAMELET_PREVIEW_NAME" <<'PY'
import hashlib
import os
from pathlib import Path, PurePosixPath
import stat
import sys
import zipfile

stage, output = map(Path, sys.argv[1:3])
name = sys.argv[3]
archive = stage / name
if archive.stat().st_size > 8 * 1024 * 1024:
    raise SystemExit("Preview ZIP exceeds 8 MiB.")
with zipfile.ZipFile(archive) as package:
    entries = package.infolist()
    if len(entries) > 512 or sum(row.file_size for row in entries) > 32 * 1024 * 1024:
        raise SystemExit("Preview ZIP exceeds its expansion budget.")
    seen = set()
    for row in entries:
        path = PurePosixPath(row.filename)
        mode = row.external_attr >> 16
        if (row.filename in seen or path.is_absolute() or ".." in path.parts
                or not path.parts or path.parts[0] not in ("Framelet.app", "__MACOSX")
                or row.filename != path.as_posix() + ("/" if row.is_dir() else "")
                or "\\" in row.filename or any(ord(char) < 32 or ord(char) == 127 for char in row.filename)
                or row.flag_bits & 1 or not (stat.S_ISREG(mode) or stat.S_ISDIR(mode))):
            raise SystemExit("Preview ZIP contains an unsafe entry.")
        seen.add(row.filename)
        data = package.read(row)
        if path.parts[0] == "__MACOSX":
            parts = path.parts[1:]
            if not parts and row.is_dir():
                continue
            if not parts:
                raise SystemExit("Preview ZIP metadata has no bundle owner.")
            if row.is_dir():
                owner_parts = parts
            elif parts[-1].startswith("._") and len(parts[-1]) > 2:
                owner_parts = (*parts[:-1], parts[-1][2:])
                if data[:8] != b"\x00\x05\x16\x07\x00\x02\x00\x00":
                    raise SystemExit("Preview ZIP metadata is not AppleDouble.")
            else:
                raise SystemExit("Preview ZIP metadata has an unsupported name.")
            if not owner_parts or owner_parts[0] != "Framelet.app":
                raise SystemExit("Preview ZIP metadata has no bundle owner.")
            owner = stage.joinpath(*owner_parts)
            if not owner.exists() or owner.is_symlink():
                raise SystemExit("Preview ZIP metadata refers to an unknown entry.")
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
with (stage / (name + ".sha256")).open("x", encoding="ascii") as destination:
    destination.write(checksum + "  " + name + "\n")
published = []
try:
    for leaf in (name, name + ".sha256"):
        source, target = stage / leaf, output / leaf
        os.link(source, target, follow_symlinks=False)
        published.append((target, source.stat()))
except BaseException:
    for target, owned in reversed(published):
        current = target.lstat()
        if (current.st_dev, current.st_ino) == (owned.st_dev, owned.st_ino):
            target.unlink()
    raise
PY
fi
if [[ -e "$FRAMELET_APP" ]]; then mv "$FRAMELET_APP" "$FRAMELET_STAGE/previous.app"; fi
mv "$FRAMELET_STAGE/Framelet.app" "$FRAMELET_APP"
if [[ "$FRAMELET_MODE" == --build-preview ]]; then FRAMELET_PREVIEW_COMPLETE=1; fi

case "$FRAMELET_MODE" in
  --build-only) echo "Built and locally ad-hoc signed: $FRAMELET_APP" ;;
  --build-preview) echo "Built a locally ad-hoc signed universal preview: $FRAMELET_DIST/$FRAMELET_PREVIEW_NAME" ;;
  --debug) lldb -- "$FRAMELET_APP/Contents/MacOS/Framelet" ;;
  --logs)
    /usr/bin/open -n "$FRAMELET_APP"
    /usr/bin/log stream --info --style compact --predicate 'process == "Framelet"'
    ;;
  --telemetry)
    /usr/bin/open -n "$FRAMELET_APP"
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.alvarovillalbaa.Framelet"'
    ;;
  --verify)
    /usr/bin/open -n "$FRAMELET_APP"
    sleep 1
    pgrep -x Framelet >/dev/null
    ;;
  run) /usr/bin/open -n "$FRAMELET_APP" ;;
esac
