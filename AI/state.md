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
- Mercury test board firmware
- STM32MP1 bare-metal firmware

## Version Authority

- Snap software actual version comes from installed snap metadata.
- Firmware expected version comes from manifests, repo metadata, or image metadata.
- Firmware actual version must be read from connected hardware through `m1tfc` or another hardware query path.

## Runtime Configuration

Runtime configuration is platform-level and lives in:

```text
/etc/m1platform
```

Active files:

- `/etc/m1platform/config.json`
- `/etc/m1platform/calibration.json`

Do not store file contents, secrets, cloud credentials, private keys, or raw calibration values in AI notes.

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

## Current Target

Target state is a 9.5-class hardware-first manufacturing test platform: repeatable build, install, debug, update, recover, and prove actual state on physical systems.