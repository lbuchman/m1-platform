# M1 Platform

This repository is the planned root repository for the M1 embedded manufacturing test platform.

Intended GitHub path:

```text
git@github.com:lbuchman/m1-platform.git
https://github.com/lbuchman/m1-platform
```

The root repository does not replace the component repositories. It documents and organizes them so the full platform can be cloned, set up, released, and recovered as one system.

## Components

| Component | Planned Repo | Local Path | Purpose |
| --- | --- | --- | --- |
| M1TFC | `git@github.com:lbuchman/m1tfc.git` | `components/m1tfc` | Fixture CLI, ICT, functional tests, hardware orchestration |
| M1 fixture Teensy firmware | `git@github.com:lbuchman/m1-fixture-teensy-fw.git` | `components/m1-fixture-teensy-fw` | Teensy firmware for M1 fixture boards |
| Mercury test board firmware | `git@github.com:lbuchman/mercury-testboard-fw.git` | `components/mercury-testboard-fw` | PlatformIO Teensy firmware for Mercury test board, aligned to the `redDiamondsFixture/teensy` skeleton |
| STM32MP1 bare-metal firmware | `git@github.com:lbuchman/stm32mp1-baremetal.git` | `components/stm32mp1-baremetal` | STM32MP1 bare-metal firmware/work; existing GitHub repo |
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

The existing `stm32mp1-baremetal` repository is handled specially. Platform-management work may add documentation, metadata, manifests, or integration notes, but must not modify Makefiles or C/C++ source files unless explicitly approved.
