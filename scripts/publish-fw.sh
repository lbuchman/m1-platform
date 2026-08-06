#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ARTIFACT_DIR="${ROOT_DIR}/artifacts"
AZURE_STORAGE_JSON="${ROOT_DIR}/azureStorage.json"
DESTINATION_URL=""
CONTAINER_NAME="firmware"
DRY_RUN=0

REQUIRED_FIRMWARE_FILES=(
    "acmfirmware.hex"
    "m1firmware.hex"
    "stm32mp1_fsbl.stm32"
)

REQUIRED_SNAP_PATTERNS=(
    "m1tfc_*.snap"
    "m1tfc-rest-server_*.snap"
    "gui-react_*.snap"
    "m1-fixture-agent_*.snap"
)

REQUIRED_METADATA_FILES=(
    "manifestFile.json"
)

usage() {
    cat <<'EOF'
Usage: scripts/publish-fw.sh [options]

Validate required build artifacts and publish artifacts/ to Azure Blob.
Accepts either an azcopy destination URL or an Azure Storage connection string
(container defaults to 'firmware').
Default destination path:
  https://<storage-account>.blob.core.windows.net/firmware

Requires an authenticated azcopy session (azcopy login), a SAS-embedded
--destination-url, or an Azure Storage connection string. If --destination-url
is not given and azureStorage.json exists at the repo root, its "conString"
value is used as the connection string.

Options:
  --destination-url URL  Full destination URL (optional SAS), or an Azure Storage connection string.
  --dry-run              Validate only; print upload plan without uploading.
  -h, --help             Show this help.

Examples:
  scripts/publish-fw.sh --destination-url 'DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...;EndpointSuffix=core.windows.net'
  scripts/publish-fw.sh --destination-url 'https://<account>.blob.core.windows.net/firmware?<sas>'
EOF
}

log() {
    printf '%s\n' "$*"
}

require_cmd() {
    local cmd="$1"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        log "ERROR: required command not found: ${cmd}"
        exit 1
    fi
}

build_destination_url() {
    printf '%s' "${DESTINATION_URL}"
}

is_connection_string() {
    [[ "${DESTINATION_URL}" == *"AccountName="* && "${DESTINATION_URL}" == *"AccountKey="* ]]
}

redact_url() {
    local url="$1"
    printf '%s' "${url%%\?*}"
}

check_manifest_file_references() {
    local manifest_path="$1"
    local -a missing_manifest_refs=()

    while IFS= read -r filename; do
        [[ -n "${filename}" ]] || continue
        if [[ ! -f "${ARTIFACT_DIR}/${filename}" ]]; then
            missing_manifest_refs+=("${filename}")
        fi
    done < <(jq -r '.[] | .filename? // empty' "${manifest_path}")

    if [[ "${#missing_manifest_refs[@]}" -gt 0 ]]; then
        log "ERROR: manifestFile.json references files that are not present in ${ARTIFACT_DIR}:"
        for filename in "${missing_manifest_refs[@]}"; do
            log "  - ${filename}"
        done
        exit 1
    fi
}

validate_required_artifacts() {
    if [[ ! -d "${ARTIFACT_DIR}" ]]; then
        log "ERROR: artifacts directory missing: ${ARTIFACT_DIR}"
        exit 1
    fi

    local file_count
    file_count=$(find "${ARTIFACT_DIR}" -type f | wc -l | tr -d ' ')
    if [[ "${file_count}" -eq 0 ]]; then
        log "ERROR: artifacts directory is empty: ${ARTIFACT_DIR}"
        exit 1
    fi

    local -a missing=()
    local -a snap_files=()

    for required_file in "${REQUIRED_FIRMWARE_FILES[@]}"; do
        if [[ ! -f "${ARTIFACT_DIR}/${required_file}" ]]; then
            missing+=("${required_file}")
        fi
    done

    for required_file in "${REQUIRED_METADATA_FILES[@]}"; do
        if [[ ! -f "${ARTIFACT_DIR}/${required_file}" ]]; then
            missing+=("${required_file}")
        fi
    done

    shopt -s nullglob
    for pattern in "${REQUIRED_SNAP_PATTERNS[@]}"; do
        local -a matches=("${ARTIFACT_DIR}"/${pattern})
        if [[ "${#matches[@]}" -eq 0 ]]; then
            missing+=("${pattern}")
            continue
        fi
        for match in "${matches[@]}"; do
            snap_files+=("$(basename "${match}")")
        done
    done
    shopt -u nullglob

    if [[ "${#missing[@]}" -gt 0 ]]; then
        log "ERROR: required artifacts are missing; upload is blocked"
        for item in "${missing[@]}"; do
            log "  - ${item}"
        done
        exit 1
    fi

    local manifest_path="${ARTIFACT_DIR}/manifestFile.json"
    if ! jq -e 'type == "array"' "${manifest_path}" >/dev/null; then
        log "ERROR: manifestFile.json must be a JSON array: ${manifest_path}"
        exit 1
    fi

    check_manifest_file_references "${manifest_path}"

    local -a missing_manifest_entries=()
    for required_file in "${REQUIRED_FIRMWARE_FILES[@]}"; do
        if ! jq -e --arg filename "${required_file}" 'map(.filename == $filename) | any' "${manifest_path}" >/dev/null; then
            missing_manifest_entries+=("${required_file}")
        fi
    done

    for snap_file in "${snap_files[@]}"; do
        if ! jq -e --arg filename "${snap_file}" 'map(.filename == $filename) | any' "${manifest_path}" >/dev/null; then
            missing_manifest_entries+=("${snap_file}")
        fi
    done

    if [[ "${#missing_manifest_entries[@]}" -gt 0 ]]; then
        log "ERROR: manifestFile.json is missing required entries; upload is blocked"
        for item in "${missing_manifest_entries[@]}"; do
            log "  - ${item}"
        done
        exit 1
    fi
}

validate_manifest_completeness_and_sha512() {
    local manifest_path="${ARTIFACT_DIR}/manifestFile.json"
    local components_dir="${ROOT_DIR}/components"
    local -a errors=()

    while IFS= read -r component; do
        [[ -n "${component}" ]] || continue
        if ! jq -e --arg component "${component}" 'map(.component == $component) | any' "${manifest_path}" >/dev/null; then
            errors+=("missing manifest entry for component: ${component}")
        fi
    done < <(find "${components_dir}" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -printf '%f\n' 2>/dev/null | sort)

    local count
    count=$(jq 'length' "${manifest_path}")
    local i
    for ((i = 0; i < count; i++)); do
        local component filename expected_sha512 actual_sha512 file_path
        component=$(jq -r ".[${i}].component // empty" "${manifest_path}")
        filename=$(jq -r ".[${i}].filename // empty" "${manifest_path}")
        expected_sha512=$(jq -r ".[${i}].sha512 // empty" "${manifest_path}")

        if [[ -z "${component}" || -z "${filename}" || -z "${expected_sha512}" ]]; then
            errors+=("manifest entry ${i} is missing component/filename/sha512")
            continue
        fi

        file_path="${ARTIFACT_DIR}/${filename}"
        if [[ ! -f "${file_path}" ]]; then
            errors+=("${filename}: artifact file not found for sha512 check")
            continue
        fi

        actual_sha512=$(sha512sum "${file_path}" | awk '{print $1}')
        if [[ "${actual_sha512}" != "${expected_sha512}" ]]; then
            errors+=("${filename}: sha512 mismatch (manifest: ${expected_sha512}, actual: ${actual_sha512})")
        fi
    done

    if [[ "${#errors[@]}" -gt 0 ]]; then
        log "ERROR: manifestFile.json failed completeness/sha512 validation; upload is blocked"
        for item in "${errors[@]}"; do
            log "  - ${item}"
        done
        exit 1
    fi
}

blob_url_for_relative_path() {
    local destination_url="$1"
    local relpath="$2"

    local base_url="${destination_url%%\?*}"
    local query=""
    if [[ "${destination_url}" == *\?* ]]; then
        query="?${destination_url#*\?}"
    fi

    printf '%s/%s%s' "${base_url%/}" "${relpath}" "${query}"
}

upload_artifacts_via_connection_string() {
    local connection_string="$1"

    log "Artifacts directory: ${ARTIFACT_DIR}"
    log "Destination: connection-string -> container '${CONTAINER_NAME}'"

    local file_count
    file_count=$(find "${ARTIFACT_DIR}" -type f | wc -l | tr -d ' ')
    log "Files to upload: ${file_count}"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "+ az storage blob upload-batch --destination ${CONTAINER_NAME} --source ${ARTIFACT_DIR} --overwrite --connection-string <redacted>"
        return
    fi

    az storage blob upload-batch \
        --destination "${CONTAINER_NAME}" \
        --source "${ARTIFACT_DIR}" \
        --overwrite \
        --connection-string "${connection_string}" >/dev/null
    log "uploaded: ${file_count} files to container '${CONTAINER_NAME}'"
}

upload_artifacts() {
    local destination_url="$1"
    local destination_display
    destination_display="$(redact_url "${destination_url}")"

    log "Artifacts directory: ${ARTIFACT_DIR}"
    log "Destination: ${destination_display}"

    local -a files=()
    while IFS= read -r -d '' file; do
        files+=("${file}")
    done < <(find "${ARTIFACT_DIR}" -type f -print0 | sort -z)

    if [[ "${#files[@]}" -eq 0 ]]; then
        log "ERROR: no files found to upload in ${ARTIFACT_DIR}"
        exit 1
    fi

    log "Files to upload: ${#files[@]}"
    for file in "${files[@]}"; do
        local relpath="${file#${ARTIFACT_DIR}/}"
        local blob_url
        blob_url="$(blob_url_for_relative_path "${destination_url}" "${relpath}")"

        if [[ "${DRY_RUN}" -eq 1 ]]; then
            log "+ azcopy copy ${file} $(redact_url "${blob_url}") --overwrite=ifSourceNewer"
            continue
        fi

        azcopy copy "${file}" "${blob_url}" --overwrite=ifSourceNewer >/dev/null
        log "uploaded: ${relpath}"
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --destination-url)
            DESTINATION_URL="${2:-}"
            if [[ -z "${DESTINATION_URL}" ]]; then
                log "ERROR: missing value for --destination-url"
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
            log "ERROR: unknown option: $1"
            usage
            exit 2
            ;;
    esac
done

require_cmd jq

validate_required_artifacts
validate_manifest_completeness_and_sha512

if [[ -z "${DESTINATION_URL}" && -f "${AZURE_STORAGE_JSON}" ]]; then
    DESTINATION_URL="$(jq -r '.conString // empty' "${AZURE_STORAGE_JSON}")"
    if [[ -z "${DESTINATION_URL}" ]]; then
        log "ERROR: ${AZURE_STORAGE_JSON} is missing a conString value"
        exit 2
    fi
    log "Using connection string from ${AZURE_STORAGE_JSON}"
fi

if [[ -z "${DESTINATION_URL}" ]]; then
    log "ERROR: upload destination is not configured"
    log "Provide --destination-url or create azureStorage.json with a conString"
    exit 2
fi

if is_connection_string; then
    require_cmd az
    upload_artifacts_via_connection_string "${DESTINATION_URL}"
else
    require_cmd azcopy
    destination_url="$(build_destination_url)"
    upload_artifacts "${destination_url}"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "Dry run complete."
else
    log "Publish completed."
fi
