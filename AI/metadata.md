# AI Metadata

This file captures repo-safe metadata needed for AI-assisted work on the M1 platform.

## Scope

- Project: M1 embedded manufacturing test platform.
- Root repo under construction: `m1-platform`.
- Local staging path: `/home/lenel/myGitHub/m1-platform-work`.
- Historical transition source: `/home/lenel/myGitHub/M1Combined`.
- Intended GitHub root path: `git@github.com:lbuchman/m1-platform.git`.

## Component Paths

```text
components/m1tfc
components/m1-fixture-teensy-fw
components/mercury-testboard-fw
components/stm32mp1-baremetal
components/m1-rest-server
components/m1-operator-ui
components/tfcroncli
components/m1-cloud-client
```

## Build Tooling

- Node target for production snaps: Node 24.
- Current local Node observed during setup: `v24.18.0`.
- Snapcraft is available on the build host.
- Root snap build script: `scripts/build-snaps.sh`.
- Build artifacts are copied to `artifacts/snaps/<timestamp>/`.

## Runtime Paths

```text
/etc/m1platform/config.json
/etc/m1platform/calibration.json
/home/lenel/logs/logfile.log
```

## Remote Development Notes

- VS Code is connected through Remote-SSH.
- Shell commands run on the remote SSH host.
- Browser `localhost` on a local workstation is not the same as remote `localhost` unless a port is forwarded.
- Development services should bind to `0.0.0.0` when remote access is needed.

## Protected Areas

- Do not modify `components/stm32mp1-baremetal` Makefiles or C/C++ source unless explicitly approved.
- Do not commit generated dependency directories or snap artifacts.
- Do not store secrets or raw calibration data in this directory.