# M1 Platform

This repository is the planned root repository for the M1 embedded manufacturing test platform.

Intended GitHub path:

```text
git@github.com:lbuchman/m1-platform.git
```

The root repository does not replace the component repositories. It documents and organizes them so the full platform can be cloned, set up, released, and recovered as one system.

## Deployment Guide

See [DEPLOY.md](DEPLOY.md) for fixture deployment instructions, required inputs, examples, and troubleshooting.

## Firmware Deployment Container (Azure Blob `deployment`)

Manual firmware releases are staged in the `deployment` Azure Blob container. See [doc/Architecture/Software/cloud-backend-migration-design.md](doc/Architecture/Software/cloud-backend-migration-design.md) for the full contract (required files, per-archive `VERSION` file format).

Requirements:

- A `manifestFile.json` is **required** in the container alongside the firmware archives.
- The [azcopy](https://learn.microsoft.com/azure/storage/common/storage-use-azcopy-v10) tool is **required** to upload/list blobs (no `az` CLI dependency).

### Installing `azcopy`

**Ubuntu / Linux:**

```bash
cd /tmp
curl -fsSL -o azcopy.tar.gz https://aka.ms/downloadazcopy-v10-linux
mkdir -p azcopy_extract
tar -xzf azcopy.tar.gz -C azcopy_extract --strip-components=1
sudo install -m 755 azcopy_extract/azcopy /usr/local/bin/azcopy
azcopy --version
```

**Windows:**

1. Download the Windows build from [https://aka.ms/downloadazcopy-v10-windows](https://aka.ms/downloadazcopy-v10-windows).
2. Extract the ZIP file.
3. Move `azcopy.exe` to a folder on your `PATH` (e.g. `C:\Tools\azcopy\`), or run it using its full path.
4. Verify with:

```powershell
azcopy --version
```

### `manifestFile.json` Format

`manifestFile.json` is a JSON array. Each entry describes one uploaded artifact:

```json
[
  {
    "filetype": "m1firmware",
    "filename": "<SAS URL to stm32mp15-lenels2-m1.txz>",
    "hash": "<sha512 of the file>"
  },
  {
    "filetype": "mnpfirmware",
    "filename": "<SAS URL to stm32mp15-lenels2-mnp.txz>",
    "hash": "<sha512 of the file>"
  }
]
```

Fields:

- `filetype`: artifact identifier (`m1firmware`, `mnpfirmware`, etc.).
- `filename`: full blob URL, including a SAS token if the blob is not public.
- `hash`: SHA-512 hex digest of the local file, used to verify integrity after download.

Compute the hash with:

```bash
sha512sum <file>.txz
```

The container **MUST** always contain both `.txz` firmware archives and a `manifestFile.json` describing them.

Firmware publishing is handled through the m1-cloud-client workflow.

Before running `scripts/publish-fw.sh`, build artifacts first:

```bash
./scripts/build-fw.sh build all --output-dir artifacts/publish/firmware
./scripts/build-snaps.sh --output-dir artifacts
```

Then publish using existing artifacts only:

```bash
./scripts/publish-fw.sh
```

## Unified Engineering Technical Support Platform

- Hardware-in-the-Loop (HIL) product validation and automation
- M1 and ACM functional simulation and validation
- Automated hardware, firmware, and software testing
- Ethernet, Serial, USB, and PoE validation infrastructure
- Firmware programming, provisioning, recovery, and regeneration
- Failure analysis, diagnostics, and remote support
- Cloud-connected updates, logs, secrets, and diagnostics
- React-based operator interface
- REST API automated test execution framework
- OSDP reader simulation
- Wiegand reader simulation
- Reader power control
- 8 supervised input simulations
- 8 supervised output simulations
- Door controller validation
- Mercury controller validation
- I/O expansion board validation
- End-to-end automated Mercury ecosystem testing

## Validation Capability Progression

Reusable Validation Platform
	-> Cycle Time Optimization
	-> Structured Measurement Collection
	-> Traceability and Data Retention
	-> Fixture Normalization
	-> Statistical Process Monitoring
	-> Anomaly Detection
	-> AI-Assisted Validation

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

| Component | Planned Repo | Local Path | Purpose |
| --- | --- | --- | --- |
| M1TFC | `git@github.com:lbuchman/m1tfc.git` | `components/m1tfc` | Fixture CLI, ICT, functional tests, hardware orchestration |
| M1 fixture Teensy firmware | `git@github.com:lbuchman/m1testBoardFw.git` | `components/m1testBoardFw` | Teensy 4.1 firmware for M1 fixture boards |
| ACM test board firmware | `git@github.com:lbuchman/acm-testboard-fw.git` | `components/acm-testboard-fw` | PlatformIO Teensy firmware for ACM test board, aligned to the `redDiamondsFixture/teensy` skeleton |
| STM32MP1 bare-metal ICT firmware | `git@github.com:lbuchman/stm32mp1-baremetal.git` | `components/stm32mp1-baremetal` | Bare-metal STM32MP1 firmware for ICT, including SDRAM test coverage unavailable when Linux owns the target |
| REST server | `git@github.com:lbuchman/m1-rest-server.git` | `components/m1-rest-server` | REST API around fixture commands and status |
| Operator UI | `git@github.com:lbuchman/m1-operator-ui.git` | `components/m1-operator-ui` | React production/debug operator interface |
| Fixture PC cloud client (`tfcroncli`, test fixture cron CLI) | `git@github.com:lbuchman/tfcroncli.git` | `components/tfcroncli` | Fixture PC cloud communication, logs, secrets, nightly FW/SW updates |
| General Ubuntu cloud client | `git@github.com:lbuchman/m1-cloud-client.git` | `components/m1-cloud-client` | Admin CLI (`m1cli uploadfw`) to upload UUT firmware and platform snap packages to Azure Cloud storage |

## Production Snaps

These platform components are production snap packages:

| Component | Local Path | Snap Packaging |
| --- | --- | --- |
| M1TFC | `components/m1tfc` | `components/m1tfc/snap/snapcraft.yaml` |
| REST server | `components/m1-rest-server` | `components/m1-rest-server/snap/snapcraft.yaml` |
| Operator UI | `components/m1-operator-ui` | `components/m1-operator-ui/snap/snapcraft.yaml` |
| Fixture PC cloud client (`tfcroncli`, test fixture cron CLI) | `components/tfcroncli` | `components/tfcroncli/snap/snapcraft.yaml` |

`m1-cloud-client` is not part of this list: it is an admin-only CLI run from an engineer's workstation to upload firmware/snap releases to Azure Cloud storage, not a fixture-side service, so it has no production snap packaging requirement.

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

The script copies built snap artifacts into `artifacts/` and writes a small `build-manifest.txt` with component names, source commits, dirty/clean state, and artifact names. `m1-cloud-client` is an admin-only CLI (not deployed to fixtures) used to upload firmware/snap releases to Azure Cloud storage, so it has no production snap packaging and is not included in this build script.

## Fast Smoke Test Checklist

Run the post-install and pre-release smoke checks in:

- `doc/fast-smoke-test-checklist.md`

## Platform Firmware Builds

Use `scripts/build-fw.sh` from the platform root to build and stage firmware
artifacts:

```bash
./scripts/build-fw.sh                     # build ACM firmware
./scripts/build-fw.sh build fixture       # build M1 fixture Teensy firmware
./scripts/build-fw.sh build stm32mp1      # build STM32MP1 ICT FSBL
./scripts/build-fw.sh build all           # build both firmware components
```

Build artifacts are copied to `artifacts/` directly.
with a `build-manifest.txt` containing the source commit and dirty/clean state.
Use `--output-dir PATH` to select another artifact directory or `--dry-run` to
inspect a command without building, installing, or programming hardware.

`build fixture` compiles `components/m1testBoardFw` with CMake using
`cross/arm-teensy41-gnueabihf.cmake` and stages `build/M1Teensy41.hex`.

### Install STM32MP1 ICT Firmware

The ICT command path reads the STM2 FSBL from `/var/m1mtf/fsbl.stm32`. Build and
install the current STM32MP1 image with:

```bash
./scripts/build-fw.sh install-stm32
```

This command builds `components/stm32mp1-baremetal/build/fsbl.stm32`, then uses
`sudo install` to place it at `/var/m1mtf/fsbl.stm32`. Use `--mtf-dir PATH` only
for a deliberately different fixture runtime directory. From inside the
STM32MP1 component, the equivalent command is `make install`; use
`MTF_DIR=PATH make install` only for a deliberately different fixture runtime
directory.

### Program ACM Test Board

ACM test board firmware is a PlatformIO Teensy 4.1 project. Build and
upload it only through an explicit ACM USB port:

```bash
./scripts/build-fw.sh program-acm \
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
