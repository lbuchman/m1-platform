#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$SCRIPT_DIR/runtime"

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
}

require_file "$RUNTIME_DIR/config.json"
require_file "$RUNTIME_DIR/calibration.json"

echo "AI-only apply mode: no host runtime files will be modified."
echo "Snapshot files available:"
echo "- $RUNTIME_DIR/config.json"
echo "- $RUNTIME_DIR/calibration.json"

if [[ -f "$RUNTIME_DIR/MANIFEST.txt" ]]; then
  echo "- $RUNTIME_DIR/MANIFEST.txt"
fi
if [[ -f "$RUNTIME_DIR/SHA256SUMS" ]]; then
  echo "- $RUNTIME_DIR/SHA256SUMS"
fi

echo "Snapshot checksums:"
sha256sum "$RUNTIME_DIR/config.json" "$RUNTIME_DIR/calibration.json"
