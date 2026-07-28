#!/bin/bash
# Remote deployment script for M1/MNP fixtures
# Usage: ./deploy.sh <ipaddress> <m1|mnp> <fixture_num>

set -euo pipefail

IP=$1
TYPE=$2
NUM=$3

if [ -z "$IP" ] || [ -z "$TYPE" ] || [ -z "$NUM" ]; then
    echo "Usage: $0 <ipaddress> <m1|mnp> <fixture_num>"
    exit 1
fi

# Ensure we are in the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TEMP_DEPLOY=""
ARCHIVE_PATH=""
ARCHIVE_NAME=""
REMOTE_ARCHIVE=""
cleanup() {
    if [ -n "$ARCHIVE_PATH" ]; then
        rm -f "$ARCHIVE_PATH"
    fi
    if [ -n "$TEMP_DEPLOY" ] && [ -d "$TEMP_DEPLOY" ]; then
        rm -rf "$TEMP_DEPLOY"
    fi
}
trap cleanup EXIT

SSH_OPTS="-o StrictHostKeyChecking=accept-new"

echo "--- Step 1: Preparing deployment package ---"
TEMP_DEPLOY=$(mktemp -d)
# Copy setup contents but exclude the snaps directory to avoid duplication
# (individual snaps will be copied to the root of TEMP_DEPLOY by get_snap)
find setup -maxdepth 1 ! -name "snaps" ! -name "setup" -exec cp -r {} "$TEMP_DEPLOY/" \;

# Include repository build artifacts in the unpacked deploy root so setup.sh
# can access them from its working directory.
if [ -d "$SCRIPT_DIR/artifacts" ]; then
    mkdir -p "$TEMP_DEPLOY/artifacts"
    cp -r "$SCRIPT_DIR/artifacts/." "$TEMP_DEPLOY/artifacts/"
fi

# Function to find or build snaps
get_snap() {
    local pattern="$1"
    local target_name="$2"
    local component="$3"

    # 1. Look in setup/snaps/ (Checked-in artifacts)
    local latest=$(ls -t setup/snaps/"$pattern"*.snap 2>/dev/null | head -n 1)
    
    # 2. Look in artifacts/ (Local build output)
    if [ -z "$latest" ]; then
        latest=$(ls -t artifacts/snaps/*/"$pattern"*.snap 2>/dev/null | head -n 1)
    fi

    # 3. Look in component dir
    if [ -z "$latest" ]; then
        latest=$(ls -t components/"$component"/"$pattern"*.snap 2>/dev/null | head -n 1)
    fi

    if [ -f "$latest" ]; then
        echo "Using snap: $latest -> $target_name"
        cp "$latest" "$TEMP_DEPLOY/$target_name"
        return 0
    else
        return 1
    fi
}

# m1client comes from tfcroncli
get_snap "m1client" "m1client.snap" "tfcroncli" || echo "Warning: m1client snap missing"

# m1tfd1 comes from m1tfd1 or m1tfc (aliased to m1tfc pattern)
get_snap "m1tfd1" "m1tfd1.snap" "m1tfc" || get_snap "m1tfc" "m1tfd1.snap" "m1tfc" || echo "Warning: m1tfd1 snap missing"

# Check if they reached the temp dir
if [ ! -f "$TEMP_DEPLOY/m1client.snap" ] || [ ! -f "$TEMP_DEPLOY/m1tfd1.snap" ]; then
    echo "Error: Required snaps (m1client, m1tfd1) could not be found or built."
    exit 1
fi

ARCHIVE_PATH="$(mktemp -p "$SCRIPT_DIR" setup_deploy.XXXXXX.tar)"
ARCHIVE_NAME="$(basename "$ARCHIVE_PATH")"
REMOTE_ARCHIVE="/home/lenel/$ARCHIVE_NAME"
tar -cf "$ARCHIVE_PATH" -C "$TEMP_DEPLOY" .
tar -tf "$ARCHIVE_PATH" > /dev/null
LOCAL_SHA=$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')

echo "--- Step 2: Transferring to $IP ---"
# Transfer to /home/lenel because /tmp might be a small tmpfs (RAM disk)
scp $SSH_OPTS "$ARCHIVE_PATH" lenel@$IP:"$REMOTE_ARCHIVE"
REMOTE_SHA=$(ssh $SSH_OPTS lenel@$IP "sha256sum '$REMOTE_ARCHIVE' | awk '{print \$1}'")
if [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
    echo "Error: Transferred archive checksum mismatch."
    exit 1
fi
rm -f "$ARCHIVE_PATH"
ARCHIVE_PATH=""

echo "--- Step 3: Executing remote setup ---"
ssh $SSH_OPTS lenel@$IP "
    set -e
    mkdir -p /home/lenel/setup_tmp && 
    cd /home/lenel/setup_tmp && 
    tar -xf '$REMOTE_ARCHIVE' && 
    echo 'lenel' | sudo -S ./setup.sh $TYPE $NUM && 
    rm -rf /home/lenel/setup_tmp '$REMOTE_ARCHIVE'
"

echo "--- Step 5: Cleanup ---"
cleanup

echo "Done."
