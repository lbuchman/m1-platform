#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/artifacts/publish"
FW_OUTPUT_DIR=""
SNAP_OUTPUT_DIR=""
FIRMWARE_MANIFEST_PATH=""
BOARDS_MANIFEST_PATH=""
CONFIG_PATH="/etc/m1platform/config.json"
M1_CLOUD_CLIENT_SRC="${ROOT_DIR}/components/m1-cloud-client/bin/m1CloudClient.js"
M1CLOUDCLIENT_RUNTIME_DIR="/tmp/m1cloudclient-runtime"
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: scripts/publish-fw.sh [options]

Ubuntu-only publish script:
    1) Read prebuilt firmware artifacts
    2) Read prebuilt snap artifacts
    3) Create firmware + boards manifests via jq
    4) Publish bundle via source m1-cloud-client publishfw (debug-friendly)

Options:
    --output-dir PATH   Base output directory (default: artifacts/publish)
    --config PATH       Config JSON for m1-cloud-client publishfw (default: /etc/m1platform/config.json)
  --dry-run           Print actions only.
  -h, --help          Show this help.
EOF
}

log() {
    printf '%s\n' "$*"
}

run() {
    log "+ $*"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        "$@"
    fi
}

require_cmd() {
    local cmd="$1"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        log "ERROR: required command not found: ${cmd}"
        exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log "ERROR: /etc/os-release not found; cannot verify Ubuntu"
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *ubuntu* ]]; then
        log "ERROR: unsupported OS (${PRETTY_NAME:-unknown}). This script supports Ubuntu only."
        exit 1
    fi
}

sha512_of() {
    sha512sum "$1" | awk '{print $1}'
}

manifest_entry_from_file() {
    local filetype="$1"
    local file="$2"
    local sha
    sha="$(sha512_of "${file}")"

    jq -cn \
        --arg filetype "${filetype}" \
        --arg filename "${file}" \
        --arg hash "${sha}" \
        '{filetype:$filetype,filename:$filename,hash:$hash}'
}

boards_entries_from_glob() {
    local filetype="$1"
    local dir="$2"

    find "${dir}" -type f | sort | while IFS= read -r file; do
        manifest_entry_from_file "${filetype}" "${file}"
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            OUTPUT_DIR="${2:-}"
            if [[ -z "${OUTPUT_DIR}" ]]; then
                log "ERROR: missing value for --output-dir"
                exit 2
            fi
            shift 2
            ;;
        --config)
            CONFIG_PATH="${2:-}"
            if [[ -z "${CONFIG_PATH}" ]]; then
                log "ERROR: missing value for --config"
                exit 2
            fi
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log "ERROR: unknown option: $1"
            usage
            exit 2
            ;;
    esac
done

check_ubuntu
require_cmd jq
require_cmd sha512sum
require_cmd node
npm_cmd=""
if command -v npm >/dev/null 2>&1; then
    npm_cmd="npm"
fi

FW_OUTPUT_DIR="${ROOT_DIR}/artifacts"
SNAP_OUTPUT_DIR="${ROOT_DIR}/artifacts"
FIRMWARE_MANIFEST_PATH="${OUTPUT_DIR}/manifestFile.json"
BOARDS_MANIFEST_PATH="${OUTPUT_DIR}/boardsManifest.json"

if [[ ! -f "${CONFIG_PATH}" ]]; then
    log "ERROR: config file not found: ${CONFIG_PATH}"
    exit 1
fi

if [[ ! -f "${M1_CLOUD_CLIENT_SRC}" ]]; then
    log "ERROR: m1-cloud-client source entry point not found: ${M1_CLOUD_CLIENT_SRC}"
    exit 1
fi

if [[ "${DRY_RUN}" -eq 0 ]]; then
    if [[ -z "${npm_cmd}" ]]; then
        log "ERROR: npm is required to bootstrap m1-cloud-client runtime dependencies"
        exit 1
    fi
    run mkdir -p "${M1CLOUDCLIENT_RUNTIME_DIR}"
    if [[ ! -d "${M1CLOUDCLIENT_RUNTIME_DIR}/node_modules" ]]; then
        run bash -lc "cd '${M1CLOUDCLIENT_RUNTIME_DIR}' && npm init -y >/dev/null"
    fi
    run bash -lc "cd '${M1CLOUDCLIENT_RUNTIME_DIR}' && npm install commander fs-extra azure-storage >/dev/null"
fi

M1_TXZ="/var/m1mtf/stm32mp15-lenels2-m1.txz"
MNP_TXZ="/var/m1mtf/stm32mp15-lenels2-mnp.txz"
if [[ ! -f "${M1_TXZ}" || ! -f "${MNP_TXZ}" ]]; then
    log "ERROR: required firmware txz files missing under /var/m1mtf"
    log "Missing check: ${M1_TXZ} and ${MNP_TXZ}"
    exit 1
fi

log "Output directory: ${OUTPUT_DIR}"
log "Snap output directory: ${SNAP_OUTPUT_DIR}"

if [[ ! -d "${FW_OUTPUT_DIR}" ]]; then
    log "ERROR: firmware artifact directory missing: ${FW_OUTPUT_DIR}"
    log "Run scripts/build-fw.sh first to populate firmware artifacts."
    exit 1
fi

if [[ ! -d "${SNAP_OUTPUT_DIR}" ]]; then
    log "ERROR: snap artifact directory missing: ${SNAP_OUTPUT_DIR}"
    log "Run scripts/build-snaps.sh first to populate snap artifacts."
    exit 1
fi

if ! find "${FW_OUTPUT_DIR}" -type f | grep -q .; then
    log "ERROR: firmware artifact directory is empty: ${FW_OUTPUT_DIR}"
    log "Run scripts/build-fw.sh first to populate firmware artifacts."
    exit 1
fi

if ! find "${SNAP_OUTPUT_DIR}" -maxdepth 1 -type f -name '*.snap' | grep -q .; then
    log "ERROR: no snap artifacts found in: ${SNAP_OUTPUT_DIR}"
    log "Run scripts/build-snaps.sh first to populate snap artifacts."
    exit 1
fi

run mkdir -p "${OUTPUT_DIR}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "Dry run complete."
    exit 0
fi

jq -n \
    --argjson m1 "$(manifest_entry_from_file m1firmware "${M1_TXZ}")" \
    --argjson mnp "$(manifest_entry_from_file mnpfirmware "${MNP_TXZ}")" \
    '[$m1, $mnp]' > "${FIRMWARE_MANIFEST_PATH}"

boards_fw_entries="$(boards_entries_from_glob boardsfw "${FW_OUTPUT_DIR}" | jq -s '.')"
boards_snap_entries="$(boards_entries_from_glob snap "${SNAP_OUTPUT_DIR}" | jq -s '.')"
jq -n \
    --argjson fw "${boards_fw_entries}" \
    --argjson snaps "${boards_snap_entries}" \
    '$fw + $snaps' > "${BOARDS_MANIFEST_PATH}"

run env NODE_PATH="${M1CLOUDCLIENT_RUNTIME_DIR}/node_modules" node "${M1_CLOUD_CLIENT_SRC}" publishfw "${FIRMWARE_MANIFEST_PATH}" "${BOARDS_MANIFEST_PATH}" "${CONFIG_PATH}"

log "Firmware manifest: ${FIRMWARE_MANIFEST_PATH}"
log "Boards manifest: ${BOARDS_MANIFEST_PATH}"
log "Publish completed."
