# AI Journal

This file records concise work history for AI-assisted platform work. Keep entries factual and repo-focused.

## 2026-07-18

- Confirmed `M1Combined` as archive and transition source.
- Confirmed `/home/lenel/myGitHub/m1-platform-work` as staged platform root.
- Added root README sections for components, production snaps, runtime configuration, snap builds, and root responsibilities.
- Documented production snap set: M1TFC, REST server, Operator UI, Fixture PC cloud client (`tfcroncli`), General Ubuntu cloud client.
- Documented firmware set: M1 fixture Teensy firmware, Mercury test board firmware, STM32MP1 bare-metal firmware.
- Moved runtime config defaults from `/var/snap/m1tfc/current` to `/etc/m1platform` in M1TFC and REST server code paths.
- Copied existing `/var/snap/m1tfc/current/config.json` and `calibration.json` to `/etc/m1platform/` on the current host.
- Added root `scripts/build-snaps.sh` for the four currently packaged snaps.
- Updated snap build flow to use `snapcraft pack`.
- Built M1TFC snap.
- Built REST server snap.
- Fixed Operator UI snapcraft recipe and built Operator UI snap.
- Identified `tfcroncli` snap build blocker around Node 24 and `better-sqlite3` native dependency compatibility.
- Confirmed `tfcroncli` uses SQLite through `app/src/secrets.js`; SQLite is not an unused dependency.
- Added root `AI/` directory for repo-owned AI state.
- Reworked `AI/` into four files: `state.md`, `metadata.md`, `journal.md`, and `calibration.md`.

## Next Work

- Finish `tfcroncli` clean snap build under Node 24.
- Add or plan snap packaging for `m1-cloud-client`.
- Add release manifests for expected snap and firmware versions.
- Add installed-state tooling for snap metadata and hardware-read firmware versions.
- Add fixture PC install and recovery documentation.