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

Mercury firmware in `components/mercury-testboard-fw` is a PlatformIO Teensy 4.1 project converted from the old CMake tree. `git@github.com:lbuchman/redDiamondsFixture.git` subdirectory `teensy/` is the reference skeleton and shared-module pattern.

`components/stm32mp1-baremetal` is a standalone STM32MP1 target firmware repository imported from `M1Combined`. It supplies the bare-metal ICT path because SDRAM is tested and cannot be owned by Linux during that test.

Observed USB identities during Mercury/M1 fixture validation:

- Mercury test board Teensy: serial `13167650`.
- M1 fixture Teensy: serial `13169080`.

Always verify board identity and expected image before flashing firmware.

## Build Tooling

- Node target for production snaps: Node 24.
- Current local Node observed during setup: `v24.18.0`.
- Snapcraft is available on the build host.
- `components/m1testBoardFw` has a PlatformIO environment (`platformio.ini`) targeting Teensy 4.1 (`teensy41`) while preserving the existing `system/` and `libs/` source layout.
- `components/m1testBoardFw` PlatformIO currently uses direct USB upload flow; remote Pi upload via `program.sh` is intentionally not integrated into the PlatformIO target.
- STM32MP1 bare-metal ICT only: Arm GNU Toolchain `12.2.MPACBTI-Rel1` at `/opt/arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi`; from `components/stm32mp1-baremetal`, source `env.sh` and run `make`.
- Root snap build script: `scripts/build-snaps.sh`.
- Build artifacts are copied to `artifacts/snaps/<timestamp>/`.

## Runtime Paths

```text
/etc/m1platform/config.json
/etc/m1platform/calibration.json
/var/m1mtf
/home/lenel/logs/logfile.log
```

`/etc/m1platform/calibration.json` is the active A/D calibration file used by M1TFC. It may be root-owned on bench systems; calibration save paths need write permission or sudo execution.

Portable state-transfer tooling:

- `AI/capture-platform-state.sh` exports `/etc/m1platform/config.json` and `/etc/m1platform/calibration.json` into `AI/runtime/`.
- `AI/apply-platform-state.sh` restores those files into `/etc/m1platform/` on another trusted PC.
- `AI/verify-platform-state.sh` validates AI context presence, snapshot checksum integrity, and target `/etc/m1platform` checksum match.
- `AI/runtime/SHA256SUMS` is generated during capture for integrity checks after transfer.

## Service Endpoints

- M1TFC REST server default bind: `0.0.0.0:3300`.
- Health endpoint: `GET /health`.
- Command endpoint: `POST /command` with `{ "command": "ict", "argument": { ... } }`.
- Logs: `GET /logs/stream`, `GET /logs/tail`, `GET /logs/download`, `POST /logs/clear`.

Mercury firmware Ethernet defaults observed on bench:

- Static IP: `192.168.0.60`.
- TCP terminal: port `23`.
- UDP terminal: port `4111`.

## Authoritative Design Docs

- Fixture electrical and operation reference: `doc/design-doc/system-diagrams/mnplus-fixture-electrical-operation-diagram.md`.
- Use this diagram as the first reference for fixture box mechanics, primary/secondary power flow, back-panel interfaces, and PoE-to-UUT routing.

## Diagram Work Index

- Primary artifact to continue: `doc/design-doc/system-diagrams/mnplus-fixture-electrical-operation-diagram.md`.
- Mandatory context before editing or answering diagram questions:
	- `AI/state.md` (see Diagram Continuation Contract)
	- `AI/journal.md` (latest dated diagram entries)
	- `doc/design-doc/system-diagrams/mnplus-fixture-electrical-operation-diagram.md` (current diagram content)
- Required output style for continuation work:
	- Keep electrical and operation updates separated.
	- Preserve explicit source-to-destination power and signal direction labels.
	- Mark any assumption as assumption, not fact.

## Remote Development Notes

- VS Code is connected through Remote-SSH.
- Shell commands run on the remote SSH host.
- Browser `localhost` on a local workstation is not the same as remote `localhost` unless a port is forwarded.
- Development services should bind to `0.0.0.0` when remote access is needed.

## Protected Areas

- Do not modify `components/stm32mp1-baremetal` Makefiles or C/C++ source unless explicitly approved.
- Do not run Linux on the STM32MP1 target during SDRAM ICT; it initializes and uses the memory being tested.
- Do not commit generated dependency directories or snap artifacts.
- Do not edit generated Snapcraft paths: `parts/`, `prime/`, `stage/`, or `*.snap` packages.
- Preserve ordered fixture I/O, retry waits, and non-awaited STM32CubeProgrammer launch behavior unless bench evidence requires a timing change.
- Do not store secrets or raw calibration data in this directory.