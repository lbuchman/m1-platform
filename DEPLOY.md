# Deploy Guide

This guide covers fixture deployment using `deploy.sh`.

## Prerequisites

- Run commands from the repository root.
- SSH access to the target host as `lenel`.
- Private key available at `setup/id_rsa`.
- Required local deploy inputs present:
  - `setup/setup.sh`
  - `setup/snaps/m1client.snap`
  - `setup/snaps/m1tfd1.snap`
  - setup assets under `setup/` (keys, netplan, rules, archives)

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
2. Resolves `m1client.snap` and `m1tfd1.snap` and includes them in payload root.
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
  - Ensure `setup/snaps/m1client.snap` and `setup/snaps/m1tfd1.snap` exist.
- Apt/network fetch errors on target:
  - Retry deployment when target network/mirror access is stable.

## Artifact Policy

- `deploy.sh` uses a temporary `setup_deploy.<random>.tar` archive as an internal artifact.
- Do not create or keep `setup_deploy.tar.gz` in this repository.
