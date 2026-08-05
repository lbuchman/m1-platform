#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ACM_COMPONENT="acm-testboard-fw"
ACM_DIR="${ROOT_DIR}/components/${ACM_COMPONENT}"
ACM_ENVIRONMENT="teensy41"
FIXTURE_COMPONENT="m1testBoardFw"
FIXTURE_DIR="${ROOT_DIR}/components/${FIXTURE_COMPONENT}"
FIXTURE_TOOLCHAIN_FILE="${FIXTURE_DIR}/cross/arm-teensy41-gnueabihf.cmake"
TEENSY_LOADER_CLI="${TEENSY_LOADER_CLI:-/home/lenel/arduino-1.8.19/hardware/tools/teensy_loader_cli}"
TEENSY_LOADER_ATTEMPTS="${TEENSY_LOADER_ATTEMPTS:-3}"
TEENSY_LOADER_TIMEOUT_SECONDS="${TEENSY_LOADER_TIMEOUT_SECONDS:-25}"
STM32_COMPONENT="stm32mp1-baremetal"
STM32_DIR="${ROOT_DIR}/components/${STM32_COMPONENT}"
MTF_DIR="/var/m1mtf"
COMMAND="build"
TARGET="all"
ARTIFACT_DIR=""
UPLOAD_PORT=""
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: scripts/build-fw.sh [command] [target] [options]

Commands:
    build [acm|fixture|stm32mp1|all]
      Build firmware and copy release artifacts into artifacts/.
      The default command is "build all" to build all firmware components.

  install-stm32
      Build the STM32MP1 ICT FSBL and install fsbl.stm32 to /var/m1mtf/.
      The installed image is read by m1tfc for DFU/SRAM ICT programming.

  program-acm
      Build and upload ACM Teensy 4.1 firmware through PlatformIO. An
      explicit --upload-port is required so two connected Teensys cannot be
      selected implicitly.

Options:
  --output-dir PATH     Copy build artifacts to PATH instead of artifacts/.
  --mtf-dir PATH        STM32 fixture runtime directory (default: /var/m1mtf).
  --upload-port PATH    Required by program-acm; explicit ACM USB port.
  --dry-run             Print actions without building, installing, or uploading.
  -h, --help            Show this help.

Examples:
  scripts/build-fw.sh
    scripts/build-fw.sh build fixture
  scripts/build-fw.sh build all
  scripts/build-fw.sh install-stm32
  scripts/build-fw.sh program-acm --upload-port /dev/serial/by-id/usb-Teensyduino_USB_Serial_13167650-if00
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

update_manifest() {
    local manifest_path="$1"
    local component="$2"
    local filename="$3"
    local commit="$4"
    local artifact_type="$5"
    local sha512="$6"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        if [[ ! -f "${manifest_path}" ]]; then
            # Create new manifest with first entry
            printf '[]\n' | jq \
                --arg component "${component}" \
                --arg filename "${filename}" \
                --arg commit "${commit}" \
                --arg type "${artifact_type}" \
                --arg sha512 "${sha512}" \
                --arg timestamp "${timestamp}" \
                '. += [{"component": $component, "filename": $filename, "commit": $commit, "type": $type, "sha512": $sha512, "timestamp": $timestamp}]' \
                > "${manifest_path}"
        else
            # Append entry to existing manifest
            jq \
                --arg component "${component}" \
                --arg filename "${filename}" \
                --arg commit "${commit}" \
                --arg type "${artifact_type}" \
                --arg sha512 "${sha512}" \
                --arg timestamp "${timestamp}" \
                '. += [{"component": $component, "filename": $filename, "commit": $commit, "type": $type, "sha512": $sha512, "timestamp": $timestamp}]' \
                "${manifest_path}" > "${manifest_path}.tmp"
            mv "${manifest_path}.tmp" "${manifest_path}"
        fi
        log "manifest: ${manifest_path}"
    fi
}

copy_artifact() {
    local component="$1"
    local artifact="$2"
    local commit="$3"
    local dirty="$4"
    local output_filename="$5"
    local destination="${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}/${output_filename}"
    local manifest_path="${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}/manifestFile.json"

    log "+ install artifact ${artifact} -> ${destination}"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        mkdir -p "$(dirname "${destination}")"
        cp -f "${artifact}" "${destination}"
        log "artifact: ${destination}"
        local sha512
        sha512=$(sha512sum "${destination}" | awk '{print $1}')
        update_manifest "${manifest_path}" "${component}" "${output_filename}" "${commit}" "firmware" "${sha512}"
    fi
}

component_revision() {
    local component_dir="$1"
    git -C "${component_dir}" rev-parse --short HEAD 2>/dev/null || printf 'unknown'
}

component_dirty_state() {
    local component_dir="$1"
    if [[ -d "${component_dir}/.git" ]] && [[ -n "$(git -C "${component_dir}" status --porcelain --untracked-files=normal)" ]]; then
        printf 'dirty'
    else
        printf 'clean'
    fi
}

extract_stm32_fw_revision() {
    local source_file="${STM32_DIR}/src/main.cc"
    if [[ ! -f "${source_file}" ]]; then
        printf 'unknown'
        return
    fi

    sed -n 's/.*fwRev[[:space:]]*=[[:space:]]*(char\*)[[:space:]]*"\([^"]*\)".*/\1/p' "${source_file}" | head -n 1
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
    local dirty
    local firmware_hex="${ACM_DIR}/.pio/build/${ACM_ENVIRONMENT}/firmware.hex"
    commit="$(component_revision "${ACM_DIR}")"
    dirty="$(component_dirty_state "${ACM_DIR}")"

    log "== ACM Test Board firmware =="
    log "source: ${ACM_DIR}"
    log "commit: ${commit} (${dirty})"
    run_in_dir "${ACM_DIR}" pio run --environment "${ACM_ENVIRONMENT}"

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        if [[ ! -f "${firmware_hex}" ]]; then
            log "No ACM firmware artifact found after build: ${firmware_hex}"
            return 1
        fi
        copy_artifact "${ACM_COMPONENT}" "${firmware_hex}" "${commit}" "${dirty}" "acmfirmware.hex"
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
    local dirty
    local fixture_hex="${FIXTURE_DIR}/.pio/build/teensy41/firmware.hex"
    commit="$(component_revision "${FIXTURE_DIR}")"
    dirty="$(component_dirty_state "${FIXTURE_DIR}")"

    log "== M1 fixture Teensy firmware =="
    log "source: ${FIXTURE_DIR}"
    log "commit: ${commit} (${dirty})"
    run_in_dir "${FIXTURE_DIR}" pio run --environment teensy41

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        if [[ ! -f "${fixture_hex}" ]]; then
            log "No fixture firmware artifact found after build: ${fixture_hex}"
            return 1
        fi
        copy_artifact "${FIXTURE_COMPONENT}" "${fixture_hex}" "${commit}" "${dirty}" "m1firmware.hex"
    fi
}

build_stm32() {
    if [[ ! -f "${STM32_DIR}/env.sh" || ! -f "${STM32_DIR}/Makefile" ]]; then
        log "Missing STM32MP1 bare-metal project: ${STM32_DIR}"
        return 1
    fi

    local commit
    local dirty
    local firmware_stm32="${STM32_DIR}/build/fsbl.stm32"
    local fw_revision
    local fw_revision_file="${STM32_DIR}/stm32mp1_rev"
    commit="$(component_revision "${STM32_DIR}")"
    dirty="$(component_dirty_state "${STM32_DIR}")"
    fw_revision="$(extract_stm32_fw_revision)"

    if [[ -z "${fw_revision}" ]]; then
        fw_revision="unknown"
    fi

    log "== STM32MP1 ICT FSBL =="
    log "source: ${STM32_DIR}"
    log "commit: ${commit} (${dirty})"
    log "fw revision: ${fw_revision}"
    log "+ (cd ${STM32_DIR} && source env.sh && make clean && make)"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        (
            cd "${STM32_DIR}"
            source env.sh
            make clean
            make
        )
        if [[ ! -f "${firmware_stm32}" ]]; then
            log "No STM32 FSBL artifact found after build: ${firmware_stm32}"
            return 1
        fi
        printf '%s\n' "${fw_revision}" > "${fw_revision_file}"
        log "revision file: ${fw_revision_file}"
        copy_artifact "${STM32_COMPONENT}" "${firmware_stm32}" "${commit}" "${dirty}" "stm32mp1_fsbl.stm32"
    fi
}

install_stm32() {
    build_stm32

    local firmware_stm32="${STM32_DIR}/build/fsbl.stm32"
    local firmware_rev="${STM32_DIR}/stm32mp1_rev"
    log "+ sudo install -D -m 0644 ${firmware_stm32} ${MTF_DIR}/fsbl.stm32"
    log "+ sudo install -D -m 0644 ${firmware_rev} ${MTF_DIR}/stm32mp1_rev"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        sudo install -D -m 0644 "${firmware_stm32}" "${MTF_DIR}/fsbl.stm32"
        sudo install -D -m 0644 "${firmware_rev}" "${MTF_DIR}/stm32mp1_rev"
        log "installed: ${MTF_DIR}/fsbl.stm32"
        log "installed: ${MTF_DIR}/stm32mp1_rev"
    fi
}

program_acm() {
    if [[ -z "${UPLOAD_PORT}" ]]; then
        log "program-acm requires --upload-port with the ACM Teensy USB path"
        exit 2
    fi

    if [[ ! -e "${UPLOAD_PORT}" ]]; then
        log "ACM upload port is not present: ${UPLOAD_PORT}"
        exit 2
    fi

    if [[ ! -x "${TEENSY_LOADER_CLI}" ]]; then
        log "Teensy loader CLI is not executable: ${TEENSY_LOADER_CLI}"
        exit 2
    fi

    build_acm
    local firmware="${ACM_DIR}/.pio/build/${ACM_ENVIRONMENT}/firmware.hex"
    log "+ timeout ${TEENSY_LOADER_TIMEOUT_SECONDS}s ${TEENSY_LOADER_CLI} --mcu=TEENSY41 -w -s -v ${firmware}"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        local attempt=1
        while [[ "${attempt}" -le "${TEENSY_LOADER_ATTEMPTS}" ]]; do
            log "ACM flash attempt ${attempt}/${TEENSY_LOADER_ATTEMPTS}"
            if timeout "${TEENSY_LOADER_TIMEOUT_SECONDS}s" "${TEENSY_LOADER_CLI}" \
                --mcu=TEENSY41 -w -s -v "${firmware}"; then
                log "ACM firmware programmed successfully"
                return
            fi
            attempt=$((attempt + 1))
        done
        log "ACM programming failed after ${TEENSY_LOADER_ATTEMPTS} attempts"
        exit 1
    fi
}

if [[ $# -gt 0 && "${1}" != -* ]]; then
    COMMAND="$1"
    shift
fi

if [[ "${COMMAND}" == "build" && $# -gt 0 && "${1}" != -* ]]; then
    TARGET="$1"
    shift
fi

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
        --mtf-dir)
            MTF_DIR="${2:-}"
            if [[ -z "${MTF_DIR}" ]]; then
                log "Missing value for --mtf-dir"
                exit 2
            fi
            shift 2
            ;;
        --upload-port)
            UPLOAD_PORT="${2:-}"
            if [[ -z "${UPLOAD_PORT}" ]]; then
                log "Missing value for --upload-port"
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

case "${COMMAND}" in
    build)
        case "${TARGET}" in
            acm)
                build_acm
                ;;
            fixture)
                build_fixture
                ;;
            stm32mp1)
                build_stm32
                ;;
            all)
                build_all_failed=0
                if ! build_acm; then
                    build_all_failed=1
                fi
                if ! build_fixture; then
                    build_all_failed=1
                fi
                if ! build_stm32; then
                    build_all_failed=1
                fi
                if [[ "${build_all_failed}" -eq 1 ]]; then
                    log ""
                    log "One or more firmware builds failed."
                    exit 1
                fi
                ;;
            *)
                log "Unknown build target: ${TARGET}"
                usage
                exit 2
                ;;
        esac
        ;;
    install-stm32)
        install_stm32
        ;;
    program-acm)
        program_acm
        ;;
    *)
        log "Unknown command: ${COMMAND}"
        usage
        exit 2
        ;;
esac
