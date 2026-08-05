#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Firmware components
ACM_COMPONENT="acm-testboard-fw"
ACM_DIR="${ROOT_DIR}/components/${ACM_COMPONENT}"
ACM_ENVIRONMENT="teensy41"
FIXTURE_COMPONENT="m1testBoardFw"
FIXTURE_DIR="${ROOT_DIR}/components/${FIXTURE_COMPONENT}"

# Teensy loader
TEENSY_LOADER_CLI="${TEENSY_LOADER_CLI:-/home/lenel/arduino-1.8.19/hardware/tools/teensy_loader_cli}"
TEENSY_LOADER_ATTEMPTS="${TEENSY_LOADER_ATTEMPTS:-3}"
TEENSY_LOADER_TIMEOUT_SECONDS="${TEENSY_LOADER_TIMEOUT_SECONDS:-25}"

# Runtime
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: scripts/prog-teensy.sh [acm|m1tb] [options]

Build and upload Teensy firmware via USB (libusb)

Board options:
  acm     Program ACM test board
  m1tb    Program M1 test board (alias: fixture)

Options:
  --dry-run             Print actions without building or uploading.
  -h, --help            Show this help.

Examples:
  scripts/prog-teensy.sh m1tb
    Build M1 fixture firmware and upload to Teensy device

  scripts/prog-teensy.sh acm
    Build ACM firmware and upload to Teensy device
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

component_revision() {
    local component_dir="$1"
    git -C "${component_dir}" rev-parse --short HEAD 2>/dev/null || printf 'unknown'
}

build_acm() {
    if [[ ! -f "${ACM_DIR}/platformio.ini" ]]; then
        log "Missing ACM PlatformIO project: ${ACM_DIR}"
        return 1
    fi
    if ! command -v pio >/dev/null 2>&1; then
        log "PlatformIO CLI 'pio' is required but was not found in PATH"
        return 1
    fi

    local commit
    local firmware_hex="${ACM_DIR}/.pio/build/${ACM_ENVIRONMENT}/firmware.hex"
    commit="$(component_revision "${ACM_DIR}")"

    log "== ACM Test Board firmware =="
    log "source: ${ACM_DIR}"
    log "commit: ${commit}"
    run_in_dir "${ACM_DIR}" pio run --environment "${ACM_ENVIRONMENT}"

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        if [[ ! -f "${firmware_hex}" ]]; then
            log "No ACM firmware artifact found after build: ${firmware_hex}"
            return 1
        fi
    fi
}

build_fixture() {
    if [[ ! -f "${FIXTURE_DIR}/platformio.ini" ]]; then
        log "Missing fixture PlatformIO project: ${FIXTURE_DIR}"
        return 1
    fi
    if ! command -v pio >/dev/null 2>&1; then
        log "PlatformIO CLI 'pio' is required but was not found in PATH"
        return 1
    fi

    local commit
    local fixture_hex="${FIXTURE_DIR}/.pio/build/teensy41/firmware.hex"
    commit="$(component_revision "${FIXTURE_DIR}")"

    log "== M1 fixture Teensy firmware =="
    log "source: ${FIXTURE_DIR}"
    log "commit: ${commit}"
    run_in_dir "${FIXTURE_DIR}" pio run --environment teensy41

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        if [[ ! -f "${fixture_hex}" ]]; then
            log "No fixture firmware artifact found after build: ${fixture_hex}"
            return 1
        fi
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
            build_acm
            firmware="${ACM_DIR}/.pio/build/${ACM_ENVIRONMENT}/firmware.hex"
            log "Hex file: ${firmware} (ACM test board)"
            ;;
        m1tb|fixture)
            build_fixture
            firmware="${FIXTURE_DIR}/.pio/build/teensy41/firmware.hex"
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
