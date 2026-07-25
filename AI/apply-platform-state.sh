#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$SCRIPT_DIR/runtime"
TARGET_DIR="/etc/m1platform"

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
}

require_file "$RUNTIME_DIR/config.json"
require_file "$RUNTIME_DIR/calibration.json"

sudo install -d -m 755 "$TARGET_DIR"
sudo install -m 644 "$RUNTIME_DIR/config.json" "$TARGET_DIR/config.json"
sudo install -m 644 "$RUNTIME_DIR/calibration.json" "$TARGET_DIR/calibration.json"

echo "Apply complete. Updated files:"
echo "- $TARGET_DIR/config.json"
echo "- $TARGET_DIR/calibration.json"

echo "Current checksums:"
sha256sum "$TARGET_DIR/config.json" "$TARGET_DIR/calibration.json"
