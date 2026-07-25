#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$SCRIPT_DIR/runtime"

CORE_FILES=(
  "$SCRIPT_DIR/README.md"
  "$SCRIPT_DIR/state.md"
  "$SCRIPT_DIR/metadata.md"
  "$SCRIPT_DIR/journal.md"
  "$SCRIPT_DIR/calibration.md"
  "$SCRIPT_DIR/capture-platform-state.sh"
  "$SCRIPT_DIR/apply-platform-state.sh"
  "$SCRIPT_DIR/verify-platform-state.sh"
)

RUNTIME_FILES=(
  "$RUNTIME_DIR/config.json"
  "$RUNTIME_DIR/calibration.json"
  "$RUNTIME_DIR/MANIFEST.txt"
  "$RUNTIME_DIR/SHA256SUMS"
)

for file in "${CORE_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing AI context file: $file" >&2
    exit 1
  fi
done

for file in "${RUNTIME_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing runtime snapshot file: $file" >&2
    exit 1
  fi
done

(
  cd "$RUNTIME_DIR"
  sha256sum -c SHA256SUMS
)

echo "Snapshot integrity check passed."
echo "AI context file presence check passed."
echo "Platform state verify passed (AI-only mode; no host runtime comparison)."
