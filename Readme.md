# M1 Platform

This repository is the root repository for the M1 embedded manufacturing test platform.

The root repository does not replace the component repositories. It documents and organizes them so the full platform can be cloned, set up, released, and recovered as one system.

## Deployment Guide

See [provision-new-pc/DEPLOY.md](provision-new-pc/DEPLOY.md) for fixture deployment instructions, required inputs, examples, and troubleshooting.

## Build PC Software Requirements

See [documentation/BuildPC/Readme.md](documentation/BuildPC/Readme.md) for the software required
on a workstation used to build platform components (Ubuntu packages, Node,
Snapcraft, VS Code/PlatformIO, and the Arm toolchain).

## Firmware Publishing

See [scripts/publish-fw.md](scripts/publish-fw.md) for publishing firmware/snap artifacts to Azure Blob storage.

## Bootstrap Components

After cloning the platform root, populate `components/` with split repositories:

```bash
./scripts/clone-components.sh
```

Cloning uses SSH git URLs (`git@github.com:...`). Use `--update` to fast-forward
existing component clones:

```bash
./scripts/clone-components.sh --update
```

To update already-present component repos without re-cloning them, use:

```bash
./scripts/update-components.sh
./scripts/update-components.sh --component m1tfc
./scripts/update-components.sh --dry-run
```

## Components

| Component | Repo | Local Path | Purpose |
| --- | --- | --- | --- |
| M1TFC | `git@github.com:lbuchman/m1tfc.git` | `components/m1tfc` | Fixture CLI, ICT, functional tests, hardware orchestration |
| M1 fixture Teensy firmware | `git@github.com:lbuchman/m1testBoardFw.git` | `components/m1testBoardFw` | Teensy 4.1 firmware for M1 fixture boards |
| ACM test board firmware | `git@github.com:lbuchman/acm-testboard-fw.git` | `components/acm-testboard-fw` | PlatformIO Teensy firmware for ACM test board, aligned to the `redDiamondsFixture/teensy` skeleton |
| STM32MP1 bare-metal ICT firmware | `git@github.com:lbuchman/stm32mp1-baremetal.git` | `components/stm32mp1-baremetal` | Bare-metal STM32MP1 firmware for ICT, including SDRAM test coverage unavailable when Linux owns the target |
| REST server | `git@github.com:lbuchman/m1-rest-server.git` | `components/m1-rest-server` | REST API around fixture commands and status |
| Operator UI | `git@github.com:lbuchman/m1-operator-ui.git` | `components/m1-operator-ui` | React production/debug operator interface |

## Production Snaps

These platform components are production snap packages:

| Component | Local Path | Snap Packaging |
| --- | --- | --- |
| M1TFC | `components/m1tfc` | `components/m1tfc/snap/snapcraft.yaml` |
| REST server | `components/m1-rest-server` | `components/m1-rest-server/snap/snapcraft.yaml` |
| Operator UI | `components/m1-operator-ui` | `components/m1-operator-ui/snap/snapcraft.yaml` |

Production snap packages should use Node 24.

## Platform Snap Builds

Use `scripts/build.sh` to build snap packages:

```bash
./scripts/build.sh build snaps
```

It builds the three snap packages that currently have snap packaging in the split workspace:

- M1TFC
- REST server
- Operator UI

Each snap can also be built individually:

```bash
./scripts/build.sh build m1tfc
./scripts/build.sh build m1-rest-server
./scripts/build.sh build m1-operator-ui
```

Use fast-forward-only git updates when a fresh build from current remotes is needed:

```bash
./scripts/build.sh build snaps --update
```

The script copies built snap artifacts into `artifacts/` and writes a small `manifestFile.json` with component names, source commits, dirty/clean state, and artifact names.

## Fast Smoke Test Checklist

Run the post-install and pre-release smoke checks in:

- [documentation/Validation/fast-smoke-test-checklist.md](documentation/Validation/fast-smoke-test-checklist.md)

## Platform Firmware Builds

Use `scripts/build.sh` from the platform root to build and stage firmware
artifacts:

```bash
./scripts/build.sh build acm        # build ACM firmware
./scripts/build.sh build fixture     # build M1 fixture Teensy firmware
./scripts/build.sh build stm32mp1    # build STM32MP1 ICT FSBL
./scripts/build.sh build firmware    # build all firmware components
./scripts/build.sh build all         # build all firmware and all snaps
```

Individual snaps can be built the same way:

```bash
./scripts/build.sh build m1tfc            # build m1tfc snap only
./scripts/build.sh build m1-rest-server   # build m1-rest-server snap only
./scripts/build.sh build m1-operator-ui   # build m1-operator-ui snap only
./scripts/build.sh build snaps            # build all snaps
```

Build artifacts are copied to `artifacts/` directly, alongside a
`build-manifest.txt` containing the source commit and dirty/clean state.
Use `--output-dir PATH` to select another artifact directory or `--dry-run` to
inspect a command without building, installing, or programming hardware.

`build fixture` compiles `components/m1testBoardFw` with PlatformIO
(`pio run --environment teensy41`) and stages the resulting `.hex` as
`artifacts/m1firmware.hex`.

### Program Teensy Boards

Upload prebuilt firmware from `artifacts/` to a Teensy board over USB with
`scripts/prog-teensy.sh`:

```bash
./scripts/prog-teensy.sh acm     # upload artifacts/acmfirmware.hex to the ACM test board
./scripts/prog-teensy.sh m1tb    # upload artifacts/m1firmware.hex to the M1 fixture board
```

This script does not build firmware; run `scripts/build.sh build acm` or
`scripts/build.sh build fixture` first to refresh the artifact. Recheck the
connected board identity before programming.

### STM32MP1 ICT Firmware

See [documentation/BuildPC/STM32MP1-ICT-FIRMWARE.md](documentation/BuildPC/STM32MP1-ICT-FIRMWARE.md) for build requirements and FSBL build/output details.

## Current Local State

The local staging path is:

```text
/home/lenel/myGitHub/m1-platform-work
```

The local component repositories are under:

```text
/home/lenel/myGitHub/m1-platform-work/components
```


