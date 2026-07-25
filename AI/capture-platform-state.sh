#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$SCRIPT_DIR/runtime"
TARGET_DIR="/etc/m1platform"

mkdir -p "$RUNTIME_DIR"

copy_from_target() {
  local src="$1"
  local dst="$2"
  if [[ -r "$src" ]]; then
    cp "$src" "$dst"
  else
    sudo cp "$src" "$dst"
    sudo chown "$(id -u):$(id -g)" "$dst"
  fi
}

copy_from_target "$TARGET_DIR/config.json" "$RUNTIME_DIR/config.json"
copy_from_target "$TARGET_DIR/calibration.json" "$RUNTIME_DIR/calibration.json"

cat > "$RUNTIME_DIR/MANIFEST.txt" <<EOF
Captured: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Source config: $TARGET_DIR/config.json
Source calibration: $TARGET_DIR/calibration.json
Host: $(hostname)
User: $(id -un)
EOF

(
  cd "$RUNTIME_DIR"
  sha256sum config.json calibration.json > SHA256SUMS
)

echo "Capture complete. Files written to: $RUNTIME_DIR"
echo "- config.json"
echo "- calibration.json"
echo "- MANIFEST.txt"
echo "- SHA256SUMS"
