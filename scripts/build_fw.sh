#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MERCURY_COMPONENT="mercury-testboard-fw"
MERCURY_DIR="${ROOT_DIR}/components/${MERCURY_COMPONENT}"
MERCURY_ENVIRONMENT="teensy41"
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
TARGET="mercury"
ARTIFACT_DIR=""
UPLOAD_PORT=""
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: scripts/build_fw.sh [command] [target] [options]

Commands:
    build [mercury|fixture|stm32mp1|all]
      Build firmware and copy release artifacts into artifacts/firmware/.
      The default command is "build mercury" for backward compatibility.

  install-stm32
      Build the STM32MP1 ICT FSBL and install fsbl.stm32 to /var/m1mtf/.
      The installed image is read by m1tfc for DFU/SRAM ICT programming.

  program-mercury
      Build and upload Mercury Teensy 4.1 firmware through PlatformIO. An
      explicit --upload-port is required so two connected Teensys cannot be
      selected implicitly.

Options:
  --output-dir PATH     Copy build artifacts to PATH instead of artifacts/firmware/.
  --mtf-dir PATH        STM32 fixture runtime directory (default: /var/m1mtf).
  --upload-port PATH    Required by program-mercury; explicit Mercury USB port.
  --dry-run             Print actions without building, installing, or uploading.
  -h, --help            Show this help.

Examples:
  scripts/build_fw.sh
    scripts/build_fw.sh build fixture
  scripts/build_fw.sh build all
  scripts/build_fw.sh install-stm32
  scripts/build_fw.sh program-mercury --upload-port /dev/serial/by-id/usb-Teensyduino_USB_Serial_13167650-if00
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

copy_artifact() {
    local component="$1"
    local artifact="$2"
    local commit="$3"
    local dirty="$4"
    local destination="${ARTIFACT_DIR:-${ROOT_DIR}/artifacts/firmware/${component}/$(date +%Y%m%d-%H%M%S)}"

    log "+ install artifact ${artifact} -> ${destination}"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        mkdir -p "${destination}"
        cp -f "${artifact}" "${destination}/"
        printf 'component=%s\ncommit=%s\nsource_state=%s\nartifact=%s\n' \
            "${component}" "${commit}" "${dirty}" "$(basename "${artifact}")" > "${destination}/build-manifest.txt"
        log "artifact: ${destination}/$(basename "${artifact}")"
        log "manifest: ${destination}/build-manifest.txt"
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

build_mercury() {
    if [[ ! -f "${MERCURY_DIR}/platformio.ini" ]]; then
        log "Missing Mercury PlatformIO project: ${MERCURY_DIR}"
        exit 1
    fi
    if ! command -v pio >/dev/null 2>&1; then
        log "PlatformIO CLI 'pio' is required but was not found in PATH"
        exit 1
    fi

    local commit
    local dirty
    local firmware_hex="${MERCURY_DIR}/.pio/build/${MERCURY_ENVIRONMENT}/firmware.hex"
    commit="$(component_revision "${MERCURY_DIR}")"
    dirty="$(component_dirty_state "${MERCURY_DIR}")"

    log "== Mercury test board firmware =="
    log "source: ${MERCURY_DIR}"
    log "commit: ${commit} (${dirty})"
    run_in_dir "${MERCURY_DIR}" pio run --environment "${MERCURY_ENVIRONMENT}"

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        if [[ ! -f "${firmware_hex}" ]]; then
            log "No Mercury firmware artifact found after build: ${firmware_hex}"
            exit 1
        fi
        copy_artifact "${MERCURY_COMPONENT}" "${firmware_hex}" "${commit}" "${dirty}"
    fi
}

build_fixture() {
    if [[ ! -f "${FIXTURE_DIR}/CMakeLists.txt" || ! -f "${FIXTURE_TOOLCHAIN_FILE}" ]]; then
        log "Missing fixture Teensy project: ${FIXTURE_DIR}"
        exit 1
    fi

    local commit
    local dirty
    local fixture_hex="${FIXTURE_DIR}/build/M1Teensy41.hex"
    commit="$(component_revision "${FIXTURE_DIR}")"
    dirty="$(component_dirty_state "${FIXTURE_DIR}")"

    log "== M1 fixture Teensy firmware =="
    log "source: ${FIXTURE_DIR}"
    log "commit: ${commit} (${dirty})"
    log "+ cmake -S ${FIXTURE_DIR} -B ${FIXTURE_DIR}/build -DCMAKE_TOOLCHAIN_FILE=${FIXTURE_TOOLCHAIN_FILE} -DCMAKE_BUILD_TYPE=Release"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        cmake -S "${FIXTURE_DIR}" -B "${FIXTURE_DIR}/build" \
            -DCMAKE_TOOLCHAIN_FILE="${FIXTURE_TOOLCHAIN_FILE}" \
            -DCMAKE_BUILD_TYPE=Release
        cmake --build "${FIXTURE_DIR}/build" -j"$(nproc)"
        if [[ ! -f "${fixture_hex}" ]]; then
            log "No fixture firmware artifact found after build: ${fixture_hex}"
            exit 1
        fi
        copy_artifact "${FIXTURE_COMPONENT}" "${fixture_hex}" "${commit}" "${dirty}"
    fi
}

build_stm32() {
    if [[ ! -f "${STM32_DIR}/env.sh" || ! -f "${STM32_DIR}/Makefile" ]]; then
        log "Missing STM32MP1 bare-metal project: ${STM32_DIR}"
        exit 1
    fi

    local commit
    local dirty
    local firmware_stm32="${STM32_DIR}/build/fsbl.stm32"
    commit="$(component_revision "${STM32_DIR}")"
    dirty="$(component_dirty_state "${STM32_DIR}")"

    log "== STM32MP1 ICT FSBL =="
    log "source: ${STM32_DIR}"
    log "commit: ${commit} (${dirty})"
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
            exit 1
        fi
        copy_artifact "${STM32_COMPONENT}" "${firmware_stm32}" "${commit}" "${dirty}"
    fi
}

install_stm32() {
    build_stm32

    local firmware_stm32="${STM32_DIR}/build/fsbl.stm32"
    log "+ sudo install -D -m 0644 ${firmware_stm32} ${MTF_DIR}/fsbl.stm32"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        sudo install -D -m 0644 "${firmware_stm32}" "${MTF_DIR}/fsbl.stm32"
        log "installed: ${MTF_DIR}/fsbl.stm32"
    fi
}

program_mercury() {
    if [[ -z "${UPLOAD_PORT}" ]]; then
        log "program-mercury requires --upload-port with the Mercury Teensy USB path"
        exit 2
    fi

    if [[ ! -e "${UPLOAD_PORT}" ]]; then
        log "Mercury upload port is not present: ${UPLOAD_PORT}"
        exit 2
    fi

    if [[ ! -x "${TEENSY_LOADER_CLI}" ]]; then
        log "Teensy loader CLI is not executable: ${TEENSY_LOADER_CLI}"
        exit 2
    fi

    build_mercury
    local firmware="${MERCURY_DIR}/.pio/build/${MERCURY_ENVIRONMENT}/firmware.hex"
    log "+ timeout ${TEENSY_LOADER_TIMEOUT_SECONDS}s ${TEENSY_LOADER_CLI} --mcu=TEENSY41 -w -s -v ${firmware}"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        local attempt=1
        while [[ "${attempt}" -le "${TEENSY_LOADER_ATTEMPTS}" ]]; do
            log "Mercury flash attempt ${attempt}/${TEENSY_LOADER_ATTEMPTS}"
            if timeout "${TEENSY_LOADER_TIMEOUT_SECONDS}s" "${TEENSY_LOADER_CLI}" \
                --mcu=TEENSY41 -w -s -v "${firmware}"; then
                log "Mercury firmware programmed successfully"
                return
            fi
            attempt=$((attempt + 1))
        done
        log "Mercury programming failed after ${TEENSY_LOADER_ATTEMPTS} attempts"
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
            mercury)
                build_mercury
                ;;
            fixture)
                build_fixture
                ;;
            stm32mp1)
                build_stm32
                ;;
            all)
                build_mercury
                build_fixture
                build_stm32
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
    program-mercury)
        program_mercury
        ;;
    *)
        log "Unknown command: ${COMMAND}"
        usage
        exit 2
        ;;
esac
