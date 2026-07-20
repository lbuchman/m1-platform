# AI State

This file captures durable working state for the M1 platform repository.

## Repository Roles

- `M1Combined` is the intact working archive and transition source.
- `/home/lenel/myGitHub/m1-platform-work` is the staged split root repo for `m1-platform`.
- The root repo owns platform documentation, setup, scripts, manifests, component links, runtime configuration rules, AI state, release process, and recovery process.
- Component repos own source code, firmware, build instructions, tests, and component-level history.

## Production Component Model

Snap software components:

- M1TFC
- REST server
- Operator UI
- Fixture PC cloud client (`tfcroncli`, test fixture cron CLI)
- General Ubuntu cloud client (`m1-cloud-client`)

Firmware components:

- M1 fixture Teensy firmware
- Mercury test board firmware: converted to a PlatformIO Teensy 4.1 Arduino project using `redDiamondsFixture/teensy` as the reference skeleton. Mercury-specific Ethernet, TCP terminal, UDP terminal, NTP, persistent config, and LED status support are restored in the PlatformIO project.
- STM32MP1 bare-metal ICT firmware: target-side firmware used while SDRAM is under test. Linux must not run during this ICT path because it initializes and uses the test subject.
- The STM32MP1 production FSBL builds from the component root `Makefile`; active source is in `src/`, headers/configuration in `include/`, vendor code in `third-party/`, and image tooling in `tools/`. It produces `build/fsbl.stm32` for bare-metal DDR/SDRAM ICT. A clean root build using the pinned Arm GNU toolchain passed on 2026-07-19 after restoring the historically renamed `STRIKE2_KICKER_POWER` symbol to its prior `GPIO::H` pin `3` assignment.

## Version Authority

- Snap software actual version comes from installed snap metadata.
- Firmware expected version comes from manifests, repo metadata, or image metadata.
- Firmware actual version must be read from connected hardware through `m1tfc` or another hardware query path.
- Mercury firmware has an `about` command returning JSON with `fw`, backed by `FWVERSION=0.1` in `components/mercury-testboard-fw/platformio.ini`.
- Latest Mercury runtime validation: Ethernet responds at `192.168.0.60`, TCP terminal listens on port `23`, and `about` over TCP returns firmware `0.1`.

## Runtime Configuration

Runtime configuration is platform-level and lives in:

```text
/etc/m1platform
```

Active files:

- `/etc/m1platform/config.json`
- `/etc/m1platform/calibration.json`

Do not store file contents, secrets, cloud credentials, private keys, or raw calibration values in AI notes.

Calibration persistence currently depends on process permission to write `/etc/m1platform/calibration.json`. REST command execution is intended to run routed `m1tfc` commands through non-interactive `sudo` so calibration writes can persist.

## REST Command State

- REST server source path: `components/m1-rest-server`.
- Local development server listens on port `3300`.
- REST `/command` routes M1TFC commands through the component command runner.
- Current command runner behavior: spawn `sudo -n m1tfc <command> ...` for both buffered and streamed command execution.

## Snap Build State

Root build command:

```bash
./scripts/build-snaps.sh
```

Use fast-forward-only component updates explicitly:

```bash
./scripts/build-snaps.sh --update
```

Latest known build state:

- M1TFC snap built.
- REST server snap built.
- Operator UI snap built after fixing its snapcraft recipe.
- `tfcroncli` snap still needs a clean successful Node 24 build after SQLite dependency updates.

Important fact: `tfcroncli` uses `better-sqlite3` in `app/src/secrets.js`; SQLite is an actual runtime dependency.

## M1TFC Fixture Behavior

- Calibration seed loading completes missing, empty, or null board profile groups from defaults while preserving populated persisted values.
- M1TFC label generation stages each print in a unique temporary directory and removes it after printing, preventing stale `/tmp` artifact collisions.
- ICT firmware download deliberately does not await STM32CubeProgrammer process teardown. The transfer completes quickly, fixed fixture delays remain, and subsequent firmware revision query verifies startup.
- `components/m1tfc` lint is clean with `npm run lint`; Snapcraft-generated `parts/`, `prime/`, and `stage/` directories are excluded from linting.

## Git Delivery State

- Root platform commit `160b07b` and REST server commit `a5459e7` are pushed to `origin/main`.
- STM32MP1 ICT firmware is published in the private `lbuchman/stm32mp1-baremetal` repository; its archive-backed `main` branch is the default. Historical remote branches remain preserved.
- M1TFC commit `70e221c`, Operator UI commit `64916a4`, and tfcroncli commit `543ac5b` exist locally. Those component repositories currently have no configured remote or upstream.

## Current Target

Target state is a 9.5-class hardware-first manufacturing test platform: repeatable build, install, debug, update, recover, and prove actual state on physical systems.