#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Prebuilt firmware artifacts
ARTIFACT_DIR="${ROOT_DIR}/artifacts"
ACM_HEX="${ARTIFACT_DIR}/acmfirmware.hex"
FIXTURE_HEX="${ARTIFACT_DIR}/m1firmware.hex"

# Teensy loader (on the remote host)
TEENSY_LOADER_CLI="${TEENSY_LOADER_CLI:-/home/lenel/arduino-1.8.19/hardware/tools/teensy_loader_cli}"
TEENSY_REBOOT="${TEENSY_REBOOT:-$(dirname "${TEENSY_LOADER_CLI}")/teensy_reboot}"
TEENSY_LOADER_ATTEMPTS="${TEENSY_LOADER_ATTEMPTS:-3}"
TEENSY_LOADER_TIMEOUT_SECONDS="${TEENSY_LOADER_TIMEOUT_SECONDS:-25}"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"

# Runtime
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: scripts/prog-teensy.sh [acm|m1tb] <host> [options]

Upload prebuilt Teensy firmware from artifacts/ to a host via scp, then
program it there via USB (libusb), since the Teensy is physically connected
to that host.

Board options:
  acm     Program ACM test board (artifacts/acmfirmware.hex)
  m1tb    Program M1 test board (artifacts/m1firmware.hex, alias: fixture)

Options:
  --dry-run             Print actions without uploading.
  -h, --help             Show this help.

Examples:
  scripts/prog-teensy.sh m1tb 192.168.1.50
    Upload artifacts/m1firmware.hex to the Teensy device on that host

  scripts/prog-teensy.sh acm 192.168.1.50
    Upload artifacts/acmfirmware.hex to the Teensy device on that host
EOF
}

log() {
    printf '%s\n' "$*"
}

program_teensy() {
    local board="${1:-}"
    local host="${2:-}"

    if [[ -z "${board}" || -z "${host}" ]]; then
        log "Error: board and host required (acm|m1tb <host>)"
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

    local remote_hex="/tmp/$(basename "${firmware}")"
    log "+ scp ${SSH_OPTS} ${firmware} lenel@${host}:${remote_hex}"
    local remote_cmd
    remote_cmd="$(cat <<EOF
set -e
attempt=1
while [ "\${attempt}" -le "${TEENSY_LOADER_ATTEMPTS}" ]; do
    echo "Flash attempt \${attempt}/${TEENSY_LOADER_ATTEMPTS}"
    if [[ "${board}" == "acm" ]]; then
        # ACM: try soft reboot path first, then direct bootloader flash fallback.
        if timeout 6s "${TEENSY_LOADER_CLI}" --mcu=TEENSY41 -w -s -v "${remote_hex}"; then
            echo "Teensy firmware programmed successfully"
            rm -f "${remote_hex}"
            exit 0
        fi

        # If soft reboot path fails, force bootloader entry and flash without -s.
        if [ -x "${TEENSY_REBOOT}" ]; then
            timeout 3s "${TEENSY_REBOOT}" >/dev/null 2>&1 || true
        fi
        if timeout $((TEENSY_LOADER_TIMEOUT_SECONDS + 10))s "${TEENSY_LOADER_CLI}" --mcu=TEENSY41 -w -v "${remote_hex}"; then
            echo "Teensy firmware programmed successfully"
            rm -f "${remote_hex}"
            exit 0
        fi
    else
        # M1TB: try soft reboot path first, then direct bootloader flash fallback.
        if timeout 6s "${TEENSY_LOADER_CLI}" --mcu=TEENSY41 -w -s -v "${remote_hex}"; then
            echo "Teensy firmware programmed successfully"
            rm -f "${remote_hex}"
            exit 0
        fi

        # If soft reboot path fails, force bootloader entry and flash without -s.
        if [ -x "${TEENSY_REBOOT}" ]; then
            timeout 3s "${TEENSY_REBOOT}" >/dev/null 2>&1 || true
        fi
        if timeout $((TEENSY_LOADER_TIMEOUT_SECONDS + 10))s "${TEENSY_LOADER_CLI}" --mcu=TEENSY41 -w -v "${remote_hex}"; then
            echo "Teensy firmware programmed successfully"
            rm -f "${remote_hex}"
            exit 0
        fi
    fi
    attempt=\$((attempt + 1))
done
echo "Programming failed after ${TEENSY_LOADER_ATTEMPTS} attempts"
rm -f "${remote_hex}"
exit 1
EOF
)"

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        scp ${SSH_OPTS} "${firmware}" "lenel@${host}:${remote_hex}"
        # shellcheck disable=SC2029
        ssh ${SSH_OPTS} "lenel@${host}" "${remote_cmd}"
    fi
}

# ===== MAIN =====

BOARD=""
HOST=""

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
            if [[ -z "${HOST}" ]]; then
                HOST="$1"
                shift
            else
                log "Unknown option or argument: $1"
                usage
                exit 2
            fi
            ;;
    esac
done

if [[ -z "${BOARD}" || -z "${HOST}" ]]; then
    log "Error: board and host required (acm|m1tb <host>)"
    usage
    exit 2
fi

program_teensy "${BOARD}" "${HOST}"

log ""
log "Done."
exit 0
