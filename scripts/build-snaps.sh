#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPONENTS=(
    "m1tfc"
    "m1-rest-server"
    "m1-operator-ui"
    "tfcroncli"
)

UPDATE=0
CLEAN=0
DRY_RUN=0
ONLY=""
ARTIFACT_DIR="${ROOT_DIR}/artifacts/snaps/$(date +%Y%m%d-%H%M%S)"

usage() {
    cat <<'EOF'
Usage: scripts/build-snaps.sh [options]

Build the current production snap packages from components/.

Options:
  --update              Fetch and fast-forward each component repo before build.
  --clean               Run snapcraft clean before each build.
  --component NAME      Build only one component.
  --output-dir PATH     Copy built snaps to PATH. Default: artifacts/snaps/<timestamp>.
  --dry-run             Print actions without changing files or building.
  --list                List buildable snap components.
  -h, --help            Show this help.

Buildable components:
  m1tfc
  m1-rest-server
  m1-operator-ui
  tfcroncli
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

run_in_dir() {
    local dir="$1"
    shift
    log "+ (cd ${dir} && $*)"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        (cd "${dir}" && "$@")
    fi
}

list_components() {
    printf '%s\n' "${COMPONENTS[@]}"
}

component_exists() {
    local component="$1"
    local known
    for known in "${COMPONENTS[@]}"; do
        [[ "${known}" == "${component}" ]] && return 0
    done
    return 1
}

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

    run git -C "${dir}" fetch --prune
    run git -C "${dir}" pull --ff-only
}

build_component() {
    local component="$1"
    local dir="${ROOT_DIR}/components/${component}"
    local snapcraft_yaml="${dir}/snap/snapcraft.yaml"
    local commit dirty newest_snap

    if [[ ! -f "${snapcraft_yaml}" ]]; then
        log "Missing ${snapcraft_yaml}"
        return 1
    fi

    log ""
    log "== ${component} =="

    if [[ "${UPDATE}" -eq 1 ]]; then
        git_fast_forward_update "${dir}"
    fi

    commit="$(git -C "${dir}" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
    dirty="clean"
    if [[ -d "${dir}/.git" ]] && [[ -n "$(git -C "${dir}" status --porcelain --untracked-files=normal)" ]]; then
        dirty="dirty"
    fi

    log "source: ${dir}"
    log "commit: ${commit} (${dirty})"

    if [[ "${CLEAN}" -eq 1 ]]; then
        run_in_dir "${dir}" snapcraft clean
    fi

    run_in_dir "${dir}" snapcraft pack

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        return 0
    fi

    newest_snap="$(find "${dir}" -maxdepth 1 -name '*.snap' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)"
    if [[ -z "${newest_snap}" ]]; then
        log "No snap artifact found in ${dir} after build"
        return 1
    fi

    mkdir -p "${ARTIFACT_DIR}"
    cp -f "${newest_snap}" "${ARTIFACT_DIR}/"
    printf '%s %s %s %s\n' "${component}" "${commit}" "${dirty}" "$(basename "${newest_snap}")" >> "${ARTIFACT_DIR}/build-manifest.txt"
    log "artifact: ${ARTIFACT_DIR}/$(basename "${newest_snap}")"
}

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
        --component)
            ONLY="${2:-}"
            if [[ -z "${ONLY}" ]]; then
                log "Missing value for --component"
                exit 2
            fi
            shift 2
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
            list_components
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

if [[ -n "${ONLY}" ]] && ! component_exists "${ONLY}"; then
    log "Unknown component: ${ONLY}"
    list_components
    exit 2
fi

if ! command -v snapcraft >/dev/null 2>&1; then
    log "snapcraft is required but was not found in PATH"
    exit 1
fi

log "Output directory: ${ARTIFACT_DIR}"

for component in "${COMPONENTS[@]}"; do
    if [[ -n "${ONLY}" && "${component}" != "${ONLY}" ]]; then
        continue
    fi
    build_component "${component}"
done

log ""
log "Done."
if [[ "${DRY_RUN}" -eq 0 ]]; then
    log "Artifacts: ${ARTIFACT_DIR}"
fi