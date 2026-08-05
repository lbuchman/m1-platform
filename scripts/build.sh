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
STM32_COMPONENT="stm32mp1-baremetal"
STM32_DIR="${ROOT_DIR}/components/${STM32_COMPONENT}"

# Snap components
SNAP_COMPONENTS=(
    "m1tfc"
    "m1-rest-server"
    "m1-operator-ui"
)

# Teensy loader
TEENSY_LOADER_CLI="${TEENSY_LOADER_CLI:-/home/lenel/arduino-1.8.19/hardware/tools/teensy_loader_cli}"
TEENSY_LOADER_ATTEMPTS="${TEENSY_LOADER_ATTEMPTS:-3}"
TEENSY_LOADER_TIMEOUT_SECONDS="${TEENSY_LOADER_TIMEOUT_SECONDS:-25}"

# Build options
COMMAND="build"
TARGET="all"
COMPONENT=""
ARTIFACT_DIR=""
UPDATE=0
CLEAN=0
DRY_RUN=0
FULL_BUILD=0
FAILED_ARTIFACTS=()
MANIFEST_CHECK_FAILED=0

usage() {
    cat <<'EOF'
Usage: scripts/build.sh [command] [target] [options]

Commands:
  build [TARGET]        Build artifacts and copy to artifacts/. Default: all
    TARGET can be:
      (empty)           Build all firmware and all snaps
      firmware          Build all firmware (acm, fixture, stm32mp1)
      snaps             Build all snaps
      acm               Build ACM test board firmware only
      fixture           Build M1 fixture firmware only
      stm32mp1          Build STM32MP1 ICT FSBL only
      m1tfc             Build m1tfc snap only
      m1-rest-server    Build m1-rest-server snap only
      m1-operator-ui    Build m1-operator-ui snap only

    A full build ("all", i.e. no TARGET) embeds each component's real git
    commit hash as its version, and is refused if any component repo has
    uncommitted changes. Building an individual TARGET always uses the
    fixed version "devbuild" instead.

  program-teensy [acm|m1tb]
    Build and upload Teensy firmware via USB (libusb)
    Board options:
      acm     Program ACM test board
      m1tb    Program M1 test board

Options:
  --update              Fetch and fast-forward component repos before build.
  --clean               Remove artifacts/ (including manifestFile.json) before
                        building, and run snapcraft clean before each snap build.
  --output-dir PATH     Copy artifacts to PATH instead of artifacts/.

  --dry-run             Print actions without building or installing.
  --list                List buildable snap components.
  -h, --help            Show this help.

Examples:
  scripts/build.sh
    Build all firmware and all snaps

  scripts/build.sh firmware
    Build all firmware

  scripts/build.sh snaps
    Build all snaps

  scripts/build.sh acm
    Build only ACM firmware

  scripts/build.sh m1tfc
    Build only m1tfc snap

  scripts/build.sh acm --dry-run
    Show what would be built for ACM without building

  scripts/build.sh program-teensy acm
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
            printf '[]\n' > "${manifest_path}"
        fi

        jq \
            --arg component "${component}" \
            --arg filename "${filename}" \
            --arg commit "${commit}" \
            --arg type "${artifact_type}" \
            --arg sha512 "${sha512}" \
            --arg timestamp "${timestamp}" \
            'map(select(.component != $component)) + [{"component": $component, "filename": $filename, "commit": $commit, "type": $type, "sha512": $sha512, "timestamp": $timestamp}]' \
            "${manifest_path}" > "${manifest_path}.tmp"
        mv "${manifest_path}.tmp" "${manifest_path}"

        log "manifest: ${manifest_path}"
    fi
}

copy_artifact() {
    local component="$1"
    local artifact="$2"
    local commit="$3"
    local output_filename="$4"
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

# Only a full "build all" run (FULL_BUILD=1) embeds the real git commit hash;
# building an individual component/target always uses "devbuild".
build_revision_for() {
    local component_dir="$1"
    if [[ "${FULL_BUILD}" -eq 1 ]]; then
        component_revision "${component_dir}"
    else
        printf 'devbuild'
    fi
}

all_build_component_dirs() {
    printf '%s\n' "${ACM_DIR}" "${FIXTURE_DIR}" "${STM32_DIR}"
    local c
    for c in "${SNAP_COMPONENTS[@]}"; do
        printf '%s\n' "${ROOT_DIR}/components/${c}"
    done
}

check_full_build_clean() {
    local dirty=0
    local d
    while IFS= read -r d; do
        if [[ "$(component_dirty_state "${d}")" == "dirty" ]]; then
            log "Component repo is dirty: ${d}"
            dirty=1
        fi
    done < <(all_build_component_dirs)
    return $dirty
}

validate_manifest() {
    local artifacts_dir="${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}"
    local manifest_path="${artifacts_dir}/manifestFile.json"
    local failed=0
    local entry_index=0

    if [[ ! -f "${manifest_path}" ]]; then
        log "Manifest validation error: missing ${manifest_path}"
        return 1
    fi

    if ! jq -e 'type == "array"' "${manifest_path}" >/dev/null 2>&1; then
        log "Manifest validation error: manifest must be a JSON array: ${manifest_path}"
        return 1
    fi

    while IFS=$'\t' read -r component filename sha512; do
        entry_index=$((entry_index + 1))

        if [[ -z "${component}" || -z "${filename}" || -z "${sha512}" ]]; then
            log "Manifest validation error: entry ${entry_index} missing component/filename/sha512"
            failed=1
            continue
        fi

        if [[ ! -d "${ROOT_DIR}/components/${component}" ]]; then
            log "Manifest validation error: entry ${entry_index} references unknown component '${component}'"
            failed=1
            continue
        fi

        if [[ ! "${sha512}" =~ ^[0-9a-fA-F]{128}$ ]]; then
            log "Manifest validation error: entry ${entry_index} has invalid sha512 format for ${filename}"
            failed=1
            continue
        fi

        local artifact_path="${artifacts_dir}/${filename}"
        if [[ ! -f "${artifact_path}" ]]; then
            log "Manifest validation error: missing artifact file ${artifact_path}"
            failed=1
            continue
        fi

        local actual_sha512
        actual_sha512=$(sha512sum "${artifact_path}" | awk '{print $1}')
        if [[ "${actual_sha512}" != "${sha512}" ]]; then
            log "Manifest validation error: sha512 mismatch for ${filename}"
            log "  expected: ${sha512}"
            log "  actual:   ${actual_sha512}"
            failed=1
        fi
    done < <(jq -r '.[] | [(.component // ""), (.filename // ""), (.sha512 // "")] | @tsv' "${manifest_path}")

    if [[ "${entry_index}" -eq 0 ]]; then
        log "Manifest validation error: manifest has no entries"
        failed=1
    fi

    while IFS= read -r component_dir; do
        [[ -n "${component_dir}" ]] || continue
        if ! jq -e --arg component "${component_dir}" 'map(.component == $component) | any' "${manifest_path}" >/dev/null 2>&1; then
            log "Manifest validation error: missing component entry for ${component_dir}"
            failed=1
        fi
    done < <(find "${ROOT_DIR}/components" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -printf '%f\n' | sort)

    if [[ "${failed}" -ne 0 ]]; then
        return 1
    fi

    log "Manifest validation: OK (${entry_index} entries)"
    return 0
}

# ===== FIRMWARE BUILDS =====

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
    commit="$(build_revision_for "${ACM_DIR}")"

    log "== ACM Test Board firmware =="
    log "source: ${ACM_DIR}"
    log "commit: ${commit}"
    FW_REV="${commit}" run_in_dir "${ACM_DIR}" pio run --environment "${ACM_ENVIRONMENT}"

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        if [[ ! -f "${firmware_hex}" ]]; then
            log "No ACM firmware artifact found after build: ${firmware_hex}"
            return 1
        fi
        copy_artifact "${ACM_COMPONENT}" "${firmware_hex}" "${commit}" "acmfirmware.hex"
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
    commit="$(build_revision_for "${FIXTURE_DIR}")"

    log "== M1 fixture Teensy firmware =="
    log "source: ${FIXTURE_DIR}"
    log "commit: ${commit}"
    FW_REV="${commit}" run_in_dir "${FIXTURE_DIR}" pio run --environment teensy41

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        if [[ ! -f "${fixture_hex}" ]]; then
            log "No fixture firmware artifact found after build: ${fixture_hex}"
            return 1
        fi
        copy_artifact "${FIXTURE_COMPONENT}" "${fixture_hex}" "${commit}" "m1firmware.hex"
    fi
}

build_stm32() {
    if [[ ! -f "${STM32_DIR}/env.sh" || ! -f "${STM32_DIR}/Makefile" ]]; then
        log "Missing STM32MP1 bare-metal project: ${STM32_DIR}"
        return 1
    fi

    local commit
    local firmware_stm32="${STM32_DIR}/build/fsbl.stm32"
    commit="$(build_revision_for "${STM32_DIR}")"

    log "== STM32MP1 ICT FSBL =="
    log "source: ${STM32_DIR}"
    log "commit: ${commit}"
    log "+ (cd ${STM32_DIR} && source env.sh && make clean && make FW_REV=${commit})"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        (
            cd "${STM32_DIR}"
            source env.sh
            make clean
            make FW_REV="${commit}"
        )
        if [[ ! -f "${firmware_stm32}" ]]; then
            log "No STM32 FSBL artifact found after build: ${firmware_stm32}"
            return 1
        fi
        copy_artifact "${STM32_COMPONENT}" "${firmware_stm32}" "${commit}" "stm32mp1_fsbl.stm32"
    fi
}

build_all_firmware() {
    local failed=0
    if ! build_acm; then
        failed=1
        FAILED_ARTIFACTS+=("acm-testboard-fw")
    fi
    if ! build_fixture; then
        failed=1
        FAILED_ARTIFACTS+=("m1testBoardFw")
    fi
    if ! build_stm32; then
        failed=1
        FAILED_ARTIFACTS+=("stm32mp1-baremetal")
    fi
    return $failed
}

program_teensy() {
    local board="${TARGET:-}"
    
    if [[ -z "${board}" ]]; then
        log "program-teensy requires a board: acm or m1tb"
        exit 2
    fi

    local prog_script="${SCRIPT_DIR}/prog-teensy.sh"
    if [[ ! -x "${prog_script}" ]]; then
        log "Program script not found or not executable: ${prog_script}"
        exit 2
    fi

    local prog_args=("${board}")
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        prog_args+=("--dry-run")
    fi

    log "Invoking ${prog_script} ${prog_args[*]}"
    "${prog_script}" "${prog_args[@]}"
}

# ===== SNAP BUILDS =====

git_fast_forward_update() {
    local dir="$1"
    local branch upstream

    if [[ ! -d "${dir}/.git" ]]; then
        log "Skipping git update for ${dir}: not a git repo"
        return 0
    fi

    branch="$(git -C "${dir}" symbolic-ref --short -q HEAD || true)"
    if [[ -z "${branch}" ]]; then
        log "Skipping git update for ${dir}: detached HEAD"
        return 0
    fi

    upstream="$(git -C "${dir}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
    if [[ -z "${upstream}" ]]; then
        log "Skipping git update for ${dir}: no upstream for ${branch}"
        return 0
    fi

    log "+ git -C ${dir} fetch --prune"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        git -C "${dir}" fetch --prune
    fi

    log "+ git -C ${dir} pull --ff-only"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        git -C "${dir}" pull --ff-only
    fi
}

build_snap_component() {
    local component="$1"
    local dir="${ROOT_DIR}/components/${component}"
    local snapcraft_yaml="${dir}/snap/snapcraft.yaml"
    local commit newest_snap

    if [[ ! -f "${snapcraft_yaml}" ]]; then
        log "Missing ${snapcraft_yaml}"
        return 1
    fi

    log ""
    log "== ${component} =="

    if [[ "${UPDATE}" -eq 1 ]]; then
        git_fast_forward_update "${dir}"
    fi

    commit="$(build_revision_for "${dir}")"

    log "source: ${dir}"
    log "commit: ${commit}"

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        find "${dir}" -maxdepth 1 -type f -name '*.snap' -delete
    fi

    if [[ "${CLEAN}" -eq 1 ]]; then
        run_in_dir "${dir}" snapcraft clean
    fi

    # Version comes from snapcraft.yaml's adopt-info part, which reads this
    # file (snapcraft's build environment does not inherit host env vars).
    local fw_rev_file="${dir}/.fw_rev"
    printf '%s' "${commit}" > "${fw_rev_file}"

    if ! run_in_dir "${dir}" snapcraft pack; then
        log "snapcraft pack failed for ${component}"
        rm -f "${fw_rev_file}"
        return 1
    fi

    rm -f "${fw_rev_file}"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        return 0
    fi

    newest_snap="$(find "${dir}" -maxdepth 1 -name '*.snap' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)"
    if [[ -z "${newest_snap}" ]]; then
        log "No snap artifact found in ${dir} after build"
        return 1
    fi

    mkdir -p "${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}"
    cp -f "${newest_snap}" "${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}/"
    local snap_dest="${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}/$(basename "${newest_snap}")"
    local sha512
    sha512=$(sha512sum "${snap_dest}" | awk '{print $1}')
    update_manifest "${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}/manifestFile.json" "${component}" "$(basename "${newest_snap}")" "${commit}" "snap" "${sha512}"
    log "artifact: ${snap_dest}"
}

build_all_snaps() {
    if ! command -v snapcraft >/dev/null 2>&1; then
        log "snapcraft is required but was not found in PATH"
        return 1
    fi

    local snap_dir="${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}"
    log "Output directory: ${snap_dir}"

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        mkdir -p "${snap_dir}"
        find "${snap_dir}" -maxdepth 1 -type f -name '*.snap' -delete
        find "${ROOT_DIR}"/components -mindepth 2 -maxdepth 2 -type f -name '*.snap' -delete
    fi

    local failed=0
    for component in "${SNAP_COMPONENTS[@]}"; do
        if ! build_snap_component "${component}"; then
            failed=1
            FAILED_ARTIFACTS+=("${component}")
        fi
    done

    return $failed
}

build_one_snap() {
    local component="$1"
    local found=0
    for known in "${SNAP_COMPONENTS[@]}"; do
        if [[ "${known}" == "${component}" ]]; then
            found=1
            break
        fi
    done

    if [[ "${found}" -eq 0 ]]; then
        log "Unknown snap component: ${component}"
        log "Known components:"
        printf '  %s\n' "${SNAP_COMPONENTS[@]}"
        return 1
    fi

    if ! command -v snapcraft >/dev/null 2>&1; then
        log "snapcraft is required but was not found in PATH"
        return 1
    fi

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        mkdir -p "${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}"
    fi

    build_snap_component "${component}"
}

# ===== MAIN DISPATCH =====

# Parse command and target
# If first arg is an option, keep COMMAND as "build"
# Otherwise, first arg is COMMAND/TARGET
if [[ $# -gt 0 && "${1}" != -* ]]; then
    COMMAND="$1"
    shift
    
    # If COMMAND is not a known top-level command, treat it as a build TARGET
    case "${COMMAND}" in
        build|program-teensy)
            # Recognized top-level command
            ;;
        *)
            # Treat as build target
            TARGET="${COMMAND}"
            COMMAND="build"
            ;;
    esac
fi

if [[ $# -gt 0 && "${1}" != -* ]]; then
    case "${COMMAND}" in
        build|program-teensy)
            TARGET="$1"
            shift
            ;;
    esac
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --update)
            UPDATE=1
            shift
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
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
        --list)
            printf 'Snap components:\n'
            printf '  %s\n' "${SNAP_COMPONENTS[@]}"
            exit 0
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

if [[ "${CLEAN}" -eq 1 && "${COMMAND}" == "build" ]]; then
    artifacts_dir="${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}"
    log "Removing ${artifacts_dir} (--clean)"
    rm -rf "${artifacts_dir}"
fi

case "${COMMAND}" in
    build)
        # parse: build [firmware|snaps|TARGET]
        case "${TARGET}" in
            ""|all)
                # build all
                FULL_BUILD=1
                if ! check_full_build_clean; then
                    log "Refusing full build: one or more component repos have uncommitted changes."
                    log "Commit or stash changes, or build an individual target (which uses 'devbuild')."
                    exit 1
                fi
                if ! build_all_firmware; then
                    :
                fi
                if ! build_all_snaps; then
                    :
                fi
                ;;
            firmware)
                # build firmware [TARGET]
                # TARGET is in next positional arg, but we already shifted
                if ! build_all_firmware; then
                    :
                fi
                ;;
            snaps)
                # build snaps [COMPONENT]
                if ! build_all_snaps; then
                    :
                fi
                ;;
            acm|fixture|stm32mp1)
                # Firmware target shorthand
                case "${TARGET}" in
                    acm) build_acm || FAILED_ARTIFACTS+=("acm-testboard-fw") ;;
                    fixture) build_fixture || FAILED_ARTIFACTS+=("m1testBoardFw") ;;
                    stm32mp1) build_stm32 || FAILED_ARTIFACTS+=("stm32mp1-baremetal") ;;
                esac
                ;;
            m1tfc|m1-rest-server|m1-operator-ui)
                # Snap component shorthand
                build_one_snap "${TARGET}" || FAILED_ARTIFACTS+=("${TARGET}")
                ;;
            *)
                log "Unknown build target: ${TARGET}"
                usage
                exit 2
                ;;
        esac
        ;;
    program-teensy)
        program_teensy
        ;;
    *)
        log "Unknown command: ${COMMAND}"
        usage
        exit 2
        ;;
esac

if [[ "${DRY_RUN}" -eq 0 && "${COMMAND}" == "build" ]]; then
    if ! validate_manifest; then
        MANIFEST_CHECK_FAILED=1
    fi
fi

log ""
log "Done."
if [[ "${DRY_RUN}" -eq 0 && "${COMMAND}" == "build" ]]; then
    log "Artifacts: ${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}"
fi

if [[ "${#FAILED_ARTIFACTS[@]}" -gt 0 ]]; then
    log "Failed artifacts: ${FAILED_ARTIFACTS[*]}"
fi

if [[ "${MANIFEST_CHECK_FAILED}" -ne 0 ]]; then
    log "Manifest validation failed."
fi

if [[ "${#FAILED_ARTIFACTS[@]}" -gt 0 || "${MANIFEST_CHECK_FAILED}" -ne 0 ]]; then
    exit 1
fi

exit 0
