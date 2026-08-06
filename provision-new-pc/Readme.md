# Deploy Guide

This guide covers fixture deployment using `deploy.sh`.

## Prerequisites

- Run commands from the repository root.
- Build PC set up per [documentation/BuildPC/Readme.md](../documentation/BuildPC/Readme.md) (Ubuntu packages, Node, Snapcraft, VS Code/PlatformIO, Arm toolchain) before building anything.
- Component repos present and current, from the repository root:
  - `./scripts/clone-components.sh` (first time), or
  - `./scripts/update-components.sh` (already cloned).
- Snap and firmware artifacts built, from the repository root:
  - `./scripts/build.sh build`
- SSH access to the target host as `lenel`, using `setup/id_rsa`:
  - Install `id_rsa` on the build machine under a distinct filename (not the
    default `~/.ssh/id_rsa`, to avoid clobbering any personal key there) —
    e.g. `~/.ssh/id_rsa_m1fixture`, mode `600`.
  - Add an entry in `~/.ssh/config` for the target PC being set up as the
    test fixture, with `IdentityFile ~/.ssh/id_rsa_m1fixture`.
- Required local deploy input: `azureStorage.json` in this directory (`provision-new-pc/`), containing the connection string from the Azure Portal — Storage account `lenels2boardsprodsa` → Access keys.

## Command

```bash
./deploy.sh <host_or_ip> <m1|mnp> <fixture_num>
```

Examples:

```bash
./deploy.sh elementsgw mnp 2
./deploy.sh 192.168.2.43 m1 5
```

## What Deploy Does

1. Builds a temporary deploy payload from `setup/`.
2. Resolves `m1tfc.snap`, `m1tfc-rest-server.snap`, and `gui-react.snap` and includes them in payload root.
3. Creates a unique temporary archive in repo root, named like `setup_deploy.<random>.tar`.
4. Copies archive to target `/home/lenel/setup_deploy.<random>.tar`.
5. Unpacks to target `/home/lenel/setup_tmp/`.
6. Runs remote setup:

```bash
sudo ./setup.sh <m1|mnp> <fixture_num>
```

7. Deletes local archive after upload checksum verification.
8. Deletes remote archive and `/home/lenel/setup_tmp/` after setup finishes.

## Success Criteria

- Script exits with code `0`.
- Remote setup log ends with:

```text
setup script completed successfully
```

## Common Failures

- SSH auth fails (`Permission denied (publickey)`):
  - Ensure `setup/id_rsa` is the key used for target host.
- Missing snaps on local machine:
  - Ensure `setup/snaps/m1tfc.snap`, `setup/snaps/m1tfc-rest-server.snap`, and `setup/snaps/gui-react.snap` exist.
- Apt/network fetch errors on target:
  - Retry deployment when target network/mirror access is stable.

## Artifact Policy

- `deploy.sh` uses a temporary `setup_deploy.<random>.tar` archive as an internal artifact.
- Do not create or keep `setup_deploy.tar.gz` in this repository.
