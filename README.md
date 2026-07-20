# M1 Platform

This repository is the planned root repository for the M1 embedded manufacturing test platform.

Intended GitHub path:

```text
git@github.com:lbuchman/m1-platform.git
https://github.com/lbuchman/m1-platform
```

The root repository does not replace the component repositories. It documents and organizes them so the full platform can be cloned, set up, released, and recovered as one system.

## Bootstrap Components

After cloning the platform root, populate `components/` with split repositories:

```bash
./scripts/clone-components.sh
```

Use `--https` when SSH keys are not configured, and `--update` to fast-forward
existing component clones:

```bash
./scripts/clone-components.sh --https
./scripts/clone-components.sh --update
```

`components/m1testBoardFw` is currently an in-platform component and is not
cloned by this script.

## Components

| Component | Planned Repo | Local Path | Purpose |
| --- | --- | --- | --- |
| M1TFC | `git@github.com:lbuchman/m1tfc.git` | `components/m1tfc` | Fixture CLI, ICT, functional tests, hardware orchestration |
| M1 fixture Teensy firmware | in-platform component | `components/m1testBoardFw` | Teensy 4.1 firmware for M1 fixture boards |
| Mercury test board firmware | `git@github.com:lbuchman/mercury-testboard-fw.git` | `components/mercury-testboard-fw` | PlatformIO Teensy firmware for Mercury test board, aligned to the `redDiamondsFixture/teensy` skeleton |
| STM32MP1 bare-metal ICT firmware | `git@github.com:lbuchman/stm32mp1-baremetal.git` | `components/stm32mp1-baremetal` | Bare-metal STM32MP1 firmware for ICT, including SDRAM test coverage unavailable when Linux owns the target |
| REST server | `git@github.com:lbuchman/m1-rest-server.git` | `components/m1-rest-server` | REST API around fixture commands and status |
| Operator UI | `git@github.com:lbuchman/m1-operator-ui.git` | `components/m1-operator-ui` | React production/debug operator interface |
| Fixture PC cloud client (`tfcroncli`, test fixture cron CLI) | `git@github.com:lbuchman/tfcroncli.git` | `components/tfcroncli` | Fixture PC cloud communication, logs, secrets, nightly FW/SW updates |
| General Ubuntu cloud client | `git@github.com:lbuchman/m1-cloud-client.git` | `components/m1-cloud-client` | General Ubuntu cloud log/update client |

## Production Snaps

These platform components are production snap packages:

| Component | Local Path | Snap Packaging |
| --- | --- | --- |
| M1TFC | `components/m1tfc` | `components/m1tfc/snap/snapcraft.yaml` |
| REST server | `components/m1-rest-server` | `components/m1-rest-server/snap/snapcraft.yaml` |
| Operator UI | `components/m1-operator-ui` | `components/m1-operator-ui/snap/snapcraft.yaml` |
| Fixture PC cloud client (`tfcroncli`, test fixture cron CLI) | `components/tfcroncli` | `components/tfcroncli/snap/snapcraft.yaml` |
| General Ubuntu cloud client | `components/m1-cloud-client` | production snap required; snap packaging still needs to be added in the split repo |

Production snap packages should use Node 24.

## Platform Snap Builds

The root repo provides a platform-level snap build script:

```bash
./scripts/build-snaps.sh
```

It builds the four snap packages that currently have snap packaging in the split workspace:

- M1TFC
- REST server
- Operator UI
- Fixture PC cloud client (`tfcroncli`, test fixture cron CLI)

Use fast-forward-only git updates when a fresh build from current remotes is needed:

```bash
./scripts/build-snaps.sh --update
```

The script copies built snap artifacts into `artifacts/snaps/<timestamp>/` and writes a small `build-manifest.txt` with component names, source commits, dirty/clean state, and artifact names. The General Ubuntu cloud client is a production snap requirement, but it is not included in this build script until `components/m1-cloud-client` has snap packaging.

## Platform Firmware Builds

Use `scripts/build_fw.sh` from the platform root to build and stage firmware
artifacts:

```bash
./scripts/build_fw.sh                     # build Mercury firmware
./scripts/build_fw.sh build fixture       # build M1 fixture Teensy firmware
./scripts/build_fw.sh build stm32mp1      # build STM32MP1 ICT FSBL
./scripts/build_fw.sh build all           # build both firmware components
```

Build artifacts are copied to `artifacts/firmware/<component>/<timestamp>/`
with a `build-manifest.txt` containing the source commit and dirty/clean state.
Use `--output-dir PATH` to select another artifact directory or `--dry-run` to
inspect a command without building, installing, or programming hardware.

`build fixture` compiles `components/m1testBoardFw` with CMake using
`cross/arm-teensy41-gnueabihf.cmake` and stages `build/M1Teensy41.hex`.

### Install STM32MP1 ICT Firmware

The ICT command path reads the STM2 FSBL from `/var/m1mtf/fsbl.stm32`. Build and
install the current STM32MP1 image with:

```bash
./scripts/build_fw.sh install-stm32
```

This command builds `components/stm32mp1-baremetal/build/fsbl.stm32`, then uses
`sudo install` to place it at `/var/m1mtf/fsbl.stm32`. Use `--mtf-dir PATH` only
for a deliberately different fixture runtime directory. From inside the
STM32MP1 component, the equivalent command is `make install`; use
`MTF_DIR=PATH make install` only for a deliberately different fixture runtime
directory.

### Program Mercury Test Board

Mercury test-board firmware is a PlatformIO Teensy 4.1 project. Build and
upload it only through an explicit Mercury USB port:

```bash
./scripts/build_fw.sh program-mercury \
	--upload-port /dev/serial/by-id/usb-Teensyduino_USB_Serial_13167650-if00
```

The serial identity above is the observed Mercury test-board identity. Recheck
the connected board identity before programming. The fixture Teensy is a
separate firmware component and must not be selected by this command.

### STM32MP1 ICT Firmware

`components/stm32mp1-baremetal` is the STM32MP1 bare-metal firmware component
used by ICT. ICT must execute without Linux running on the target: SDRAM is a
test subject, so Linux cannot own, initialize, or use the memory under test.
The component is therefore a standalone firmware repository, separate from the
Snap-packaged host-side tools.

Its build requires Arm GNU Toolchain `12.2.MPACBTI-Rel1` at:

```text
/opt/arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi
```

This `arm-none-eabi` toolchain is required only by
`components/stm32mp1-baremetal`. It is not the Node toolchain used by Snap
components or the PlatformIO toolchain used by Teensy firmware. GNU Make and
Python 3 are also required.

Build the FSBL from the component root:

```bash
cd components/stm32mp1-baremetal
source env.sh
arm-none-eabi-gcc --version
make clean
make
```

`env.sh` must be sourced in the same shell as `make`; it adds the required ARM
compiler and binutils to `PATH`.

The STM32MP1 component builds from its root `Makefile`; its active firmware
layout is `src/`, `include/`, `third-party/`, and `tools/`. A successful build
produces:

```text
build/fsbl.elf
build/fsbl.bin
build/fsbl.stm32
```

`build/fsbl.stm32` is the STM2 BootROM image to use for the target. It includes
the BootROM header and checksum generated from the `.bin` artifact; do not use
the `.elf` or `.bin` in its place.

`make` only builds the image. `make install` stages the built FSBL at
`/var/m1mtf/fsbl.stm32` for the normal ICT command path. `make load` is a
separate interactive SD-media operation that writes the first two boot
partitions; run it only after the approved provisioning path and target device
identity have been verified.

## TODO: Define `/var/m1mtf` Before Production Use

**BLOCKING TODO:** `/var/m1mtf` is currently the shared, user-independent
fixture runtime directory used by `m1tfc`, the REST service, and React-launched
commands running through `sudo`. It is expected to hold fixture firmware,
image directories, logs, and the ICT FSBL at `/var/m1mtf/fsbl.stm32`.

The platform does not yet define this directory as a production contract.
Before a fixture can be installed, recovered, or released reliably, define and
automate all of the following:

- directory ownership, group access, permissions, and service-account access;
- required subdirectory layout and which component owns each file;
- how release artifacts, including `fsbl.stm32`, are installed and versioned;
- what is persistent fixture state versus regenerable build or log output;
- cleanup, retention, backup, recovery, and upgrade behavior;
- installation-time validation that `/etc/m1platform/config.json` points
	`mtfDir` to the provisioned directory.

Do not rely on a per-user `$HOME/m1mtf` fallback: `sudo m1tfc` would resolve it
as `/root/m1mtf`, breaking the shared fixture path contract.

## Platform Runtime Configuration

M1 platform runtime configuration files live in:

```text
/etc/m1platform
```

The active files are:

| File | Purpose |
| --- | --- |
| `/etc/m1platform/config.json` | Fixture and site runtime configuration used by M1TFC and the REST server |
| `/etc/m1platform/calibration.json` | A/D calibration data for M1 test boards; keeps calibration data for up to 20 M1 test boards |

These files were moved out of the snap runtime path so local debug runs and production snap runs use the same configuration location.

## Root Repository Responsibilities

- platform architecture documentation
- component list and repo links
- AI state, metadata, journal, and calibration notes under `AI/`
- PC setup guide
- platform scripts
- release manifests
- current production version pointer
- config and calibration rules
- future CAD/drawing package references

## Current Local State

The local staging path is:

```text
/home/lenel/myGitHub/m1-platform-work
```

The local component repositories are under:

```text
/home/lenel/myGitHub/m1-platform-work/components
```

## Branch Policy

New component repositories use `main`.

The `stm32mp1-baremetal` repository is handled specially. Platform-management work may add documentation, metadata, manifests, or integration notes, but must not modify Makefiles or C/C++ source files unless explicitly approved.
