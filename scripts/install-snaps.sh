#!/usr/bin/env bash
# Copies each built snap to a host via scp and installs it there via ssh.
# Usage: scripts/install-snaps.sh <host>
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 <host>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARTIFACT_DIR="${ARTIFACT_DIR:-${ROOT_DIR}/artifacts}"
HOST="$1"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"

# component -> "snap-name-prefix:snap-install-flags"
SNAPS=(
    "m1tfc:m1tfc:--classic"
    "m1-rest-server:m1tfc-rest-server:--classic"
    "m1-operator-ui:gui-react:"
    "m1-fixture-agent:m1-fixture-agent:--classic"
)

if [[ ! -d "${ARTIFACT_DIR}" ]]; then
    echo "Artifacts directory not found: ${ARTIFACT_DIR}" >&2
    exit 1
fi

for entry in "${SNAPS[@]}"; do
    IFS=':' read -r component prefix flags <<< "${entry}"

    snap_file="$(find "${ARTIFACT_DIR}" -maxdepth 1 -name "${prefix}_*_amd64.snap" -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)"
    if [[ -z "${snap_file}" ]]; then
        echo "No ${prefix}_*_amd64.snap found in ${ARTIFACT_DIR} for ${component}" >&2
        exit 1
    fi

    local_name="$(basename "${snap_file}")"
    echo "Installing ${component} on ${HOST}: ${local_name}"
    scp ${SSH_OPTS} "${snap_file}" "lenel@${HOST}:/tmp/${local_name}"
    # shellcheck disable=SC2029
    ssh ${SSH_OPTS} "lenel@${HOST}" "sudo snap install --dangerous ${flags} /tmp/${local_name} && rm -f /tmp/${local_name}"
done
