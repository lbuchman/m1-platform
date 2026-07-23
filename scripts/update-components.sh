#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPONENTS_DIR="${ROOT_DIR}/components"
DRY_RUN=0
SELECTED_COMPONENT=""

usage() {
    cat <<'EOF'
Usage: scripts/update-components.sh [options]

Update existing split component repositories under components/.

Options:
  --component NAME   Update only one component
  --dry-run          Print planned updates without changing anything
  -h, --help         Show this help

Examples:
  ./scripts/update-components.sh
  ./scripts/update-components.sh --dry-run
  ./scripts/update-components.sh --component m1tfc
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --component)
            if [[ $# -lt 2 ]]; then
                echo "Missing value for --component" >&2
                exit 2
            fi
            SELECTED_COMPONENT="$2"
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
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

components=(
    "m1tfc"
    "m1testBoardFw"
    "mercury-testboard-fw"
    "stm32mp1-baremetal"
    "m1-rest-server"
    "m1-operator-ui"
    "tfcroncli"
    "m1-cloud-client"
)

if [[ -n "${SELECTED_COMPONENT}" ]]; then
    if [[ ! " ${components[*]} " =~ " ${SELECTED_COMPONENT} " ]]; then
        echo "Unknown component: ${SELECTED_COMPONENT}" >&2
        exit 2
    fi
    components=("${SELECTED_COMPONENT}")
fi

for component in "${components[@]}"; do
    target_dir="${COMPONENTS_DIR}/${component}"

    if [[ ! -d "${target_dir}/.git" ]]; then
        echo "skip: ${target_dir} (not a git repo)"
        continue
    fi

    echo "==> ${component}"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "  [dry-run] git -C ${target_dir} pull --ff-only"
    else
        (
            cd "${target_dir}"
            git pull --ff-only
        )
    fi
done
