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
| Mercury test board firmware | `git@github.com:lbuchman/mercury-testboard-fw.git` | `components/mercury-testboard-fw` | Teensy firmware for Mercury test board |
| STM32MP1 bare-metal firmware | `git@github.com:lbuchman/stm32mp1-baremetal.git` | `components/stm32mp1-baremetal` | STM32MP1 bare-metal firmware/work; existing GitHub repo |
| REST server | `git@github.com:lbuchman/m1-rest-server.git` | `components/m1-rest-server` | REST API around fixture commands and status |
| Operator UI | `git@github.com:lbuchman/m1-operator-ui.git` | `components/m1-operator-ui` | React production/debug operator interface |
| Fixture PC cloud client | `git@github.com:lbuchman/tfcroncli.git` | `components/tfcroncli` | Fixture PC cloud communication, logs, secrets, nightly FW/SW updates |
| General Ubuntu cloud client | `git@github.com:lbuchman/m1-cloud-client.git` | `components/m1-cloud-client` | General Ubuntu cloud log/update client |

## Root Repository Responsibilities

- platform architecture documentation
- component list and repo links
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
