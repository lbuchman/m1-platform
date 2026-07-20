#!/usr/bin/env bash
set -euo pipefail

# Scan component folders and report Git cleanliness.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
platform_root="$(cd "${script_dir}/.." && pwd)"
components_root="${1:-${platform_root}/components}"

if [[ ! -d "${components_root}" ]]; then
    echo "Components directory not found: ${components_root}" >&2
    exit 1
fi

echo "Checking components in: ${components_root}"

dirty_count=0
clean_count=0
not_git_count=0
parent_repo_count=0

for comp_path in "${components_root}"/*; do
    [[ -d "${comp_path}" ]] || continue

    comp_name="$(basename "${comp_path}")"

    if ! git -C "${comp_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf "%-35s %s\n" "${comp_name}" "NOT_GIT"
        ((not_git_count+=1))
        continue
    fi

    repo_root="$(git -C "${comp_path}" rev-parse --show-toplevel)"
    if [[ "${repo_root}" != "${comp_path}" ]]; then
        printf "%-35s %s (%s)\n" "${comp_name}" "PARENT_REPO" "$(basename "${repo_root}")"
        ((parent_repo_count+=1))
        continue
    fi

    status="$(git -C "${comp_path}" status --porcelain --untracked-files=normal)"
    if [[ -n "${status}" ]]; then
        printf "%-35s %s\n" "${comp_name}" "DIRTY"
        ((dirty_count+=1))
    else
        printf "%-35s %s\n" "${comp_name}" "CLEAN"
        ((clean_count+=1))
    fi
done

echo
echo "Summary: CLEAN=${clean_count} DIRTY=${dirty_count} PARENT_REPO=${parent_repo_count} NOT_GIT=${not_git_count}"

if [[ ${dirty_count} -gt 0 ]]; then
    exit 2
fi
