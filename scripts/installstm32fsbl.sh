#!/usr/bin/env bash
# Copy the latest built STM32MP1 ICT FSBL to /var/m1mtf/fsbl.stm32 on a host.
# Usage: scripts/installstm32fsbl.sh <host>
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 <host>" >&2
    exit 1
fi

HOST="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FSBL_FILE="${ROOT_DIR}/artifacts/stm32mp1_fsbl.stm32"

if [[ ! -f "${FSBL_FILE}" ]]; then
    echo "ERROR: ${FSBL_FILE} not found. Build it first: scripts/build.sh stm32mp1" >&2
    exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=accept-new"

echo "Copying ${FSBL_FILE} -> lenel@${HOST}:/tmp/fsbl.stm32"
scp ${SSH_OPTS} "${FSBL_FILE}" "lenel@${HOST}:/tmp/fsbl.stm32"

echo "Installing to /var/m1mtf/fsbl.stm32 on ${HOST}"
ssh ${SSH_OPTS} "lenel@${HOST}" "sudo cp -f /tmp/fsbl.stm32 /var/m1mtf/fsbl.stm32 && sudo chown lenel: /var/m1mtf/fsbl.stm32 && rm -f /tmp/fsbl.stm32"

echo "Done."
