#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPONENTS_DIR="${ROOT_DIR}/components"
CLONE_MODE="ssh"
DO_UPDATE=0

usage() {
    cat <<'EOF'
Usage: scripts/clone-components.sh [options]

Clone all split component repositories into components/.

Options:
  --https      Use HTTPS clone URLs
  --ssh        Use SSH clone URLs (default)
  --update     Fast-forward pull existing component repos
  -h, --help   Show this help

Examples:
  ./scripts/clone-components.sh
  ./scripts/clone-components.sh --https
  ./scripts/clone-components.sh --update
EOF
}

log() {
    printf '%s\n' "$*"
}

clone_or_update_component() {
    local name="$1"
    local ssh_url="$2"
    local https_url="$3"
    local repo_url
    local target_dir="${COMPONENTS_DIR}/${name}"

    if [[ "${CLONE_MODE}" == "https" ]]; then
        repo_url="${https_url}"
    else
        repo_url="${ssh_url}"
    fi

    if [[ -d "${target_dir}/.git" ]]; then
        log "exists: ${target_dir}"
        if [[ "${DO_UPDATE}" -eq 1 ]]; then
            log "+ (cd ${target_dir} && git pull --ff-only)"
            (cd "${target_dir}" && git pull --ff-only)
        fi
        return
    fi

    if [[ -e "${target_dir}" ]]; then
        log "skip: ${target_dir} exists but is not a git repo"
        return
    fi

    log "+ git clone ${repo_url} ${target_dir}"
    git clone "${repo_url}" "${target_dir}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --https)
            CLONE_MODE="https"
            shift
            ;;
        --ssh)
            CLONE_MODE="ssh"
            shift
            ;;
        --update)
            DO_UPDATE=1
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

mkdir -p "${COMPONENTS_DIR}"

clone_or_update_component "m1tfc" \
    "git@github.com:lbuchman/m1tfc.git" \
    "https://github.com/lbuchman/m1tfc.git"

clone_or_update_component "mercury-testboard-fw" \
    "git@github.com:lbuchman/mercury-testboard-fw.git" \
    "https://github.com/lbuchman/mercury-testboard-fw.git"

clone_or_update_component "stm32mp1-baremetal" \
    "git@github.com:lbuchman/stm32mp1-baremetal.git" \
    "https://github.com/lbuchman/stm32mp1-baremetal.git"

clone_or_update_component "m1-rest-server" \
    "git@github.com:lbuchman/m1-rest-server.git" \
    "https://github.com/lbuchman/m1-rest-server.git"

clone_or_update_component "m1-operator-ui" \
    "git@github.com:lbuchman/m1-operator-ui.git" \
    "https://github.com/lbuchman/m1-operator-ui.git"

clone_or_update_component "tfcroncli" \
    "git@github.com:lbuchman/tfcroncli.git" \
    "https://github.com/lbuchman/tfcroncli.git"

clone_or_update_component "m1-cloud-client" \
    "git@github.com:lbuchman/m1-cloud-client.git" \
    "https://github.com/lbuchman/m1-cloud-client.git"

log ""
log "Note: components/m1testBoardFw is currently an in-platform component and is not cloned by this script."
log "Done."
