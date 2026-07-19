#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPONENT="mercury-testboard-fw"
COMPONENT_DIR="${ROOT_DIR}/components/${COMPONENT}"
ENVIRONMENT="teensy41"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/firmware/${COMPONENT}/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: scripts/build_fw.sh [options]

Build Mercury test board firmware without uploading it to hardware.

Options:
  --output-dir PATH     Copy the firmware artifact to PATH.
  --dry-run             Print actions without building or copying artifacts.
  -h, --help            Show this help.
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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            ARTIFACT_DIR="${2:-}"
            if [[ -z "${ARTIFACT_DIR}" ]]; then
                log "Missing value for --output-dir"
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
            log "Unknown option: $1"
            usage
            exit 2
            ;;
    esac
done

if [[ ! -f "${COMPONENT_DIR}/platformio.ini" ]]; then
    log "Missing Mercury PlatformIO project: ${COMPONENT_DIR}"
    exit 1
fi

if ! command -v pio >/dev/null 2>&1; then
    log "PlatformIO CLI 'pio' is required but was not found in PATH"
    exit 1
fi

commit="$(git -C "${COMPONENT_DIR}" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
dirty="clean"
if [[ -d "${COMPONENT_DIR}/.git" ]] && [[ -n "$(git -C "${COMPONENT_DIR}" status --porcelain --untracked-files=normal)" ]]; then
    dirty="dirty"
fi

log "== Mercury test board firmware =="
log "source: ${COMPONENT_DIR}"
log "commit: ${commit} (${dirty})"
run_in_dir "${COMPONENT_DIR}" pio run --environment "${ENVIRONMENT}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
    exit 0
fi

firmware_hex="${COMPONENT_DIR}/.pio/build/${ENVIRONMENT}/firmware.hex"
if [[ ! -f "${firmware_hex}" ]]; then
    log "No firmware artifact found after build: ${firmware_hex}"
    exit 1
fi

mkdir -p "${ARTIFACT_DIR}"
cp -f "${firmware_hex}" "${ARTIFACT_DIR}/"
printf 'component=%s\ncommit=%s\nsource_state=%s\nartifact=%s\n' \
    "${COMPONENT}" "${commit}" "${dirty}" "$(basename "${firmware_hex}")" > "${ARTIFACT_DIR}/build-manifest.txt"

log "artifact: ${ARTIFACT_DIR}/$(basename "${firmware_hex}")"
log "manifest: ${ARTIFACT_DIR}/build-manifest.txt"