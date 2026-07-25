#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$SCRIPT_DIR/runtime"
TARGET_DIR="/etc/m1platform"

CORE_FILES=(
  "$SCRIPT_DIR/README.md"
  "$SCRIPT_DIR/state.md"
  "$SCRIPT_DIR/metadata.md"
  "$SCRIPT_DIR/journal.md"
  "$SCRIPT_DIR/calibration.md"
  "$SCRIPT_DIR/capture-platform-state.sh"
  "$SCRIPT_DIR/apply-platform-state.sh"
)

RUNTIME_FILES=(
  "$RUNTIME_DIR/config.json"
  "$RUNTIME_DIR/calibration.json"
  "$RUNTIME_DIR/SHA256SUMS"
)

readable_hash() {
  local file="$1"
  if [[ -r "$file" ]]; then
    sha256sum "$file" | awk '{print $1}'
    return 0
  fi
  sudo sha256sum "$file" | awk '{print $1}'
}

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

if [[ ! -f "$TARGET_DIR/config.json" || ! -f "$TARGET_DIR/calibration.json" ]]; then
  echo "Target runtime files not present in $TARGET_DIR yet."
  echo "Run apply script first: $SCRIPT_DIR/apply-platform-state.sh"
  exit 0
fi

snap_cfg_hash="$(readable_hash "$RUNTIME_DIR/config.json")"
snap_cal_hash="$(readable_hash "$RUNTIME_DIR/calibration.json")"
live_cfg_hash="$(readable_hash "$TARGET_DIR/config.json")"
live_cal_hash="$(readable_hash "$TARGET_DIR/calibration.json")"

status=0

if [[ "$snap_cfg_hash" == "$live_cfg_hash" ]]; then
  echo "Config match: OK"
else
  echo "Config match: MISMATCH" >&2
  echo "Snapshot: $snap_cfg_hash" >&2
  echo "Target:   $live_cfg_hash" >&2
  status=1
fi

if [[ "$snap_cal_hash" == "$live_cal_hash" ]]; then
  echo "Calibration match: OK"
else
  echo "Calibration match: MISMATCH" >&2
  echo "Snapshot: $snap_cal_hash" >&2
  echo "Target:   $live_cal_hash" >&2
  status=1
fi

if [[ $status -eq 0 ]]; then
  echo "Platform state verify passed."
else
  echo "Platform state verify failed." >&2
fi

exit $status
