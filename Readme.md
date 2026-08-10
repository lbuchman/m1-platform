# M1 Platform

This repository is the root repository for the M1 embedded manufacturing test platform.

The root repository does not replace the component repositories. It documents and organizes them so the full platform can be cloned, set up, released, and recovered as one system.

## Top-Level Directory Structure

| Directory | Purpose |
| --- | --- |
| `artifacts/` | Build output (snaps, firmware images, manifest) produced by `scripts/build.sh`. |
| `components/` | Independently git-tracked component repos (`m1tfc`, `m1testBoardFw`, `acm-testboard-fw`, `stm32mp1-baremetal`, `m1-rest-server`, `m1-operator-ui`), populated via `scripts/clone-components.sh`. |
| `documentation/` | Controlled documentation baseline: architecture, hardware, assembly, operations, validation, sustainment, and cloud-deployment docs. |
| `provision-new-pc/` | Fixture PC provisioning and deployment tooling (`setup.sh`, `deploy.sh`, required inputs). |
| `scripts/` | Automation scripts: build, clone/update components, publish firmware, program Teensy boards. |

## Build PC Software Requirements

Ubuntu is required for development — other OSes (macOS, Windows, WSL, other Linux distros) are not
supported for building or running this platform's build/deploy tooling. Ubuntu 26.04 LTS is recommended.
See [documentation/BuildPC/Readme.md](documentation/BuildPC/Readme.md) for the exact release and required
software: Ubuntu packages, Node, Snapcraft, VS Code/PlatformIO, and the Arm toolchain.

## Build the Platform

From the repository root, after cloning components (see [Bootstrap Components](#bootstrap-components) below):

```bash
./scripts/build.sh build
```

Builds all firmware and all snaps, staging artifacts in `artifacts/` alongside `manifestFile.json`.

## Fixture PC Deployment Guide

See [provision-new-pc/Readme.md](provision-new-pc/Readme.md) for fixture deployment instructions, required inputs, examples, and troubleshooting.

## Firmware Publishing

See [scripts/publish-fw.md](scripts/publish-fw.md) for publishing firmware/snap artifacts to Azure Blob storage.

## Bootstrap Components

After cloning the platform root, populate `components/` with split repositories:

```bash
./scripts/clone-components.sh
```

See [scripts/Readme.md](scripts/Readme.md) for update/dry-run options and the rest of the automation scripts.

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

See [scripts/Readme.md](scripts/Readme.md#buildsh-usage) for full `build.sh` firmware/snap target usage and options.

## Fast Smoke Test Checklist

Run the post-install and pre-release smoke checks in:

- [documentation/Validation/fast-smoke-test-checklist.md](documentation/Validation/fast-smoke-test-checklist.md)

## Platform Firmware Builds

See [scripts/Readme.md](scripts/Readme.md#buildsh-usage) for full `build.sh` firmware/snap target usage and options.

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

## Repository Layout

- Repository root: this directory.
- Component repositories: `components/` (relative to repository root), populated by `scripts/clone-components.sh`.


