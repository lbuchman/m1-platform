#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Prebuilt firmware artifacts
ARTIFACT_DIR="${ROOT_DIR}/artifacts"
ACM_HEX="${ARTIFACT_DIR}/acmfirmware.hex"
FIXTURE_HEX="${ARTIFACT_DIR}/m1firmware.hex"

# Teensy loader
TEENSY_LOADER_CLI="${TEENSY_LOADER_CLI:-/home/lenel/arduino-1.8.19/hardware/tools/teensy_loader_cli}"
TEENSY_LOADER_ATTEMPTS="${TEENSY_LOADER_ATTEMPTS:-3}"
TEENSY_LOADER_TIMEOUT_SECONDS="${TEENSY_LOADER_TIMEOUT_SECONDS:-25}"

# Runtime
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: scripts/prog-teensy.sh [acm|m1tb] [options]

Upload prebuilt Teensy firmware from artifacts/ via USB (libusb)

Board options:
  acm     Program ACM test board (artifacts/acmfirmware.hex)
  m1tb    Program M1 test board (artifacts/m1firmware.hex, alias: fixture)

Options:
  --dry-run             Print actions without uploading.
  -h, --help            Show this help.

Examples:
  scripts/prog-teensy.sh m1tb
    Upload artifacts/m1firmware.hex to Teensy device

  scripts/prog-teensy.sh acm
    Upload artifacts/acmfirmware.hex to Teensy device
EOF
}

log() {
    printf '%s\n' "$*"
}

run_in_dir() {
    local dir="$1"
    shift
    log "+ (cd ${dir} && $*)"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        (cd "${dir}" && "$@")
    fi
}

program_teensy() {
    local board="${1:-}"
    
    if [[ -z "${board}" ]]; then
        log "Error: board required (acm or m1tb)"
        exit 2
    fi
    
    if [[ ! -x "${TEENSY_LOADER_CLI}" ]]; then
        log "Teensy loader CLI is not executable: ${TEENSY_LOADER_CLI}"
        exit 2
    fi

    local firmware
    case "${board}" in
        acm)
            firmware="${ACM_HEX}"
            log "Hex file: ${firmware} (ACM test board)"
            ;;
        m1tb|fixture)
            firmware="${FIXTURE_HEX}"
            log "Hex file: ${firmware} (M1 test board)"
            ;;
        *)
            log "Unknown board: ${board}. Use 'acm' or 'm1tb'"
            exit 2
            ;;
    esac

    if [[ ! -f "${firmware}" ]]; then
        log "Hex file not found: ${firmware}"
        exit 1
    fi

    log "+ timeout ${TEENSY_LOADER_TIMEOUT_SECONDS}s ${TEENSY_LOADER_CLI} --mcu=TEENSY41 -w -s -v ${firmware}"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        local attempt=1
        while [[ "${attempt}" -le "${TEENSY_LOADER_ATTEMPTS}" ]]; do
            log "Flash attempt ${attempt}/${TEENSY_LOADER_ATTEMPTS}"
            if timeout "${TEENSY_LOADER_TIMEOUT_SECONDS}s" "${TEENSY_LOADER_CLI}" \
                --mcu=TEENSY41 -w -s -v "${firmware}"; then
                log "Teensy firmware programmed successfully"
                return
            fi
            attempt=$((attempt + 1))
        done
        log "Programming failed after ${TEENSY_LOADER_ATTEMPTS} attempts"
        exit 1
    fi
}

# ===== MAIN =====

BOARD=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        acm|m1tb|fixture)
            BOARD="$1"
            shift
            ;;
        *)
            log "Unknown option or board: $1"
            usage
            exit 2
            ;;
    esac
done

if [[ -z "${BOARD}" ]]; then
    log "Error: board required (acm or m1tb)"
    usage
    exit 2
fi

program_teensy "${BOARD}"

log ""
log "Done."
exit 0
