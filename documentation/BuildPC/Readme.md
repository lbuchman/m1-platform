# Build PC Software Requirements

Software required on a workstation used to build `m1-platform-work` components
(firmware, Snap packages, and Teensy/PlatformIO firmware).

## OS

Ubuntu is required for development — other OSes (macOS, Windows, WSL, other Linux distros) are not
supported for building or running this platform's build/deploy tooling. Ubuntu 26.04 LTS is recommended
(matching `base: core22` used by the platform Snaps).

## Base packages

```bash
sudo apt update
sudo apt install -y build-essential make git python3 python3-pip
```

- `build-essential` / `make` — required by `components/stm32mp1-baremetal` and
  general native builds.
- `git` — component subrepos are each independently git-tracked.
- `python3` — required alongside `make` by the STM32MP1 bare-metal build (see
  [STM32MP1-ICT-FIRMWARE.md](STM32MP1-ICT-FIRMWARE.md)).

## Node.js

Node 24.x is required to build and run the Snap-packaged components
(`m1tfc`, `m1-rest-server`, `m1-operator-ui`). Install via
[nvm](https://github.com/nvm-sh/nvm) or the NodeSource repository:

```bash
nvm install 24
nvm use 24
node -v
```

## Snapcraft

Required to build the platform Snaps (`m1tfc`, `m1tfc-rest-server`,
`gui-react`, all `base: core22`):

```bash
sudo snap install snapcraft --classic
sudo snap install lxd
sudo usermod -aG lxd $USER
sudo lxd init --auto
```

Log out and back in (or `newgrp lxd`) after the `usermod` step for the group
change to take effect.

## VS Code + PlatformIO

Install [VS Code](https://code.visualstudio.com/) with the **PlatformIO IDE**
extension. Required to build and program:

- `components/acm-testboard-fw` — PlatformIO Teensy firmware for the ACM test
  board.
- `components/m1testBoardFw` — M1 fixture Teensy firmware, built via
  PlatformIO (`pio run --environment teensy41`).

## Arm GNU Toolchain

Required only for `components/stm32mp1-baremetal` (STM32MP1 ICT bare-metal
FSBL). See [STM32MP1-ICT-FIRMWARE.md](STM32MP1-ICT-FIRMWARE.md) for the exact
toolchain version, install path, and build steps — it is a separate,
standalone `arm-none-eabi` toolchain, distinct from the Node and PlatformIO
toolchains used elsewhere on this platform.

## Other

- `curl` — used to exercise the REST server locally (`curl
  http://localhost:3300/config`) during verification.
- SSH access configured for `github.com:lbuchman/*` component repos (each
  `components/*` folder is pushed/pulled independently).
