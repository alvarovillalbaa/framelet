#!/usr/bin/env bash
set -euo pipefail

FRAMELET_MODE="${1:-run}"
case "$FRAMELET_MODE" in
  run|--build-only|--debug|--logs|--telemetry|--verify) ;;
  *) echo "usage: $0 [--build-only|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
FRAMELET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$FRAMELET_ROOT"
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
  if [[ "$FRAMELET_MODE" == --build-only ]]; then
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

swift build --product Framelet
FRAMELET_BINARY="$(swift build --show-bin-path)/Framelet"
FRAMELET_DIST="$FRAMELET_ROOT/dist"
FRAMELET_APP="$FRAMELET_DIST/Framelet.app"
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
  if [[ ! -e "$FRAMELET_APP" && -d "$FRAMELET_STAGE/previous.app" ]]; then
    mv "$FRAMELET_STAGE/previous.app" "$FRAMELET_APP"
  fi
  rm -rf "$FRAMELET_STAGE"
}
trap cleanup_framelet_stage EXIT
mkdir -p "$FRAMELET_STAGE/Framelet.app/Contents/MacOS"
cp "$FRAMELET_BINARY" "$FRAMELET_STAGE/Framelet.app/Contents/MacOS/Framelet"
cp "$FRAMELET_ROOT/Resources/Info.plist" "$FRAMELET_STAGE/Framelet.app/Contents/Info.plist"
chmod +x "$FRAMELET_STAGE/Framelet.app/Contents/MacOS/Framelet"
/usr/bin/plutil -lint "$FRAMELET_STAGE/Framelet.app/Contents/Info.plist"
# Local ad-hoc signing uses no certificate, account, network, or paid enrollment.
/usr/bin/codesign --force --sign - "$FRAMELET_STAGE/Framelet.app"
/usr/bin/codesign --verify --strict "$FRAMELET_STAGE/Framelet.app"
if [[ -e "$FRAMELET_APP" ]]; then mv "$FRAMELET_APP" "$FRAMELET_STAGE/previous.app"; fi
mv "$FRAMELET_STAGE/Framelet.app" "$FRAMELET_APP"

case "$FRAMELET_MODE" in
  --build-only) echo "Built and locally ad-hoc signed: $FRAMELET_APP" ;;
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
