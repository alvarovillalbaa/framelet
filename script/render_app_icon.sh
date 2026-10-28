#!/usr/bin/env bash
set -euo pipefail

FRAMELET_ICON_MODE="${1:-export}"
[[ $# -le 1 ]] || { echo "usage: $0 [--check]" >&2; exit 2; }
case "$FRAMELET_ICON_MODE" in
  export|--check) ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac
FRAMELET_ICON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRAMELET_ICON_MASTER="$FRAMELET_ICON_ROOT/artwork/app-icon.svg"
[[ -f "$FRAMELET_ICON_MASTER" ]] || { echo "The editable SVG master is missing." >&2; exit 1; }
command -v python3 >/dev/null || { echo "Python 3 is required to render the SVG master." >&2; exit 1; }
FRAMELET_ICON_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/framelet-icon.XXXXXX")"
cleanup_framelet_icon_stage() { rm -rf "$FRAMELET_ICON_STAGE"; }
trap cleanup_framelet_icon_stage EXIT
mkdir "$FRAMELET_ICON_STAGE/AppIcon.iconset"

while read -r FRAMELET_ICON_POINTS FRAMELET_ICON_SCALE FRAMELET_ICON_PIXELS; do
  FRAMELET_ICON_SUFFIX=""
  [[ "$FRAMELET_ICON_SCALE" == 1 ]] || FRAMELET_ICON_SUFFIX="@2x"
  python3 "$FRAMELET_ICON_ROOT/script/render_app_icon.py" --size "$FRAMELET_ICON_PIXELS" \
    --output "$FRAMELET_ICON_STAGE/AppIcon.iconset/icon_${FRAMELET_ICON_POINTS}x${FRAMELET_ICON_POINTS}${FRAMELET_ICON_SUFFIX}.png"
done <<'ICON_SIZES'
16 1 16
16 2 32
32 1 32
32 2 64
128 1 128
128 2 256
256 1 256
256 2 512
512 1 512
512 2 1024
ICON_SIZES

python3 "$FRAMELET_ICON_ROOT/script/render_app_icon.py" --pack-iconset "$FRAMELET_ICON_STAGE/AppIcon.iconset" \
  --output "$FRAMELET_ICON_STAGE/AppIcon.icns"
FRAMELET_ICON_PREVIEW="$FRAMELET_ICON_STAGE/AppIcon.iconset/icon_512x512@2x.png"
if [[ "$FRAMELET_ICON_MODE" == --check ]]; then
  cmp -s "$FRAMELET_ICON_PREVIEW" "$FRAMELET_ICON_ROOT/artwork/app-icon.png" || { echo "The PNG preview differs from this host's SVG export." >&2; exit 1; }
  cmp -s "$FRAMELET_ICON_STAGE/AppIcon.icns" "$FRAMELET_ICON_ROOT/Resources/AppIcon.icns" || { echo "AppIcon.icns differs from this host's SVG export." >&2; exit 1; }
  echo "Framelet PNG and ten-slot ICNS match this host's SVG export."
else
  cp "$FRAMELET_ICON_PREVIEW" "$FRAMELET_ICON_ROOT/artwork/app-icon.png"
  cp "$FRAMELET_ICON_STAGE/AppIcon.icns" "$FRAMELET_ICON_ROOT/Resources/AppIcon.icns"
  echo "Exported Framelet's original PNG preview and ten-slot ICNS."
fi
