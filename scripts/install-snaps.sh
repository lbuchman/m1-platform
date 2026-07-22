#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: scripts/install-snaps.sh [DIR]

Install all .snap files from DIR. If DIR is omitted, the script uses the most
recent artifacts/snaps/<timestamp> directory under the repository root.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

TARGET_DIR="${1:-}"

if [[ -z "${TARGET_DIR}" ]]; then
    LATEST_DIR="$(find "${ROOT_DIR}/artifacts/snaps" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1 || true)"
    if [[ -z "${LATEST_DIR}" ]]; then
        echo "No snap artifact directories found under ${ROOT_DIR}/artifacts/snaps" >&2
        exit 1
    fi
    TARGET_DIR="${LATEST_DIR}"
fi

if [[ ! -d "${TARGET_DIR}" ]]; then
    echo "Directory not found: ${TARGET_DIR}" >&2
    exit 1
fi

shopt -s nullglob
SNAPS=("${TARGET_DIR}"/*.snap)
shopt -u nullglob

if [[ ${#SNAPS[@]} -eq 0 ]]; then
    echo "No .snap files found in ${TARGET_DIR}" >&2
    exit 1
fi

for snap in "${SNAPS[@]}"; do
    echo "Installing $(basename "${snap}")"
    sudo snap install --dangerous "${snap}"
done
