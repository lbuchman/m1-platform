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
- Converted Mercury test board firmware to a PlatformIO Teensy 4.1 project using `redDiamondsFixture/teensy` as the reference skeleton and shared-module pattern.
- Restored Mercury PlatformIO firmware networking stack: NativeEthernet setup, TCP terminal, UDP terminal, NTP client, persistent network config, and LED status support.
- Built and flashed Mercury firmware to the Mercury Teensy board after verifying board identity; latest build reports `FWVERSION=0.1`.
- Validated Mercury Ethernet at `192.168.0.60`: ping succeeds, TCP port `23` accepts connections, `about`, `ifconfig`, `help`, and `getalldata` respond over TCP.
- Confirmed M1 fixture Teensy board ID read path through `getfwrev`; observed board ID `2` on the current bench fixture.
- Tested M1TFC A/D calibration lookup by changing active board slot `2` TP305 scale in `/etc/m1platform/calibration.json`; ICT calibration run showed TP305 scaled value changing, proving calibration lookup is active.
- Found calibration persistence issue: `saveCalibration()` suppresses write errors, and root-owned `/etc/m1platform/calibration.json` prevents normal-user calibration saves.
- Updated REST command runner so routed M1TFC commands execute through `sudo -n`; updated and passed `components/m1-rest-server` tests.
- Restarted local REST development server from `components/m1-rest-server`; health endpoint responded on port `3300`.

## 2026-07-19

- Confirmed `components/stm32mp1-baremetal` as a standalone local firmware repository imported from `M1Combined`; generated build output is excluded from the import.
- Documented its ICT purpose: SDRAM is the test subject, so the STM32MP1 target must run bare-metal rather than Linux during SDRAM ICT.
- Added `READMEConfig.md` documenting fixture configuration and calibration behavior.
- Updated M1TFC calibration seed handling to fill incomplete profiles from defaults while retaining populated persisted data; added focused Jest coverage.
- Changed M1TFC label printing to use unique temporary staging directories and cleanup; added focused Jest coverage.
- Preserved asynchronous STM32CubeProgrammer launch and fixed fixture delays after confirming programmer teardown must not control ICT timing.
- Updated operator UI log behavior: production shows failures, debug shows full logs, clear calls the backend, and failed runs show a debug summary.
- Added Snapcraft artifact ignores and removed tracked Snap packages across the root and component repositories.
- Resolved M1TFC ESLint findings without changing ordered hardware/retry execution; `npm run lint` passes.
- Committed and pushed root platform `160b07b` and REST server `a5459e7`; committed M1TFC `70e221c`, Operator UI `64916a4`, and tfcroncli `543ac5b` locally.
- Published the private `lbuchman/stm32mp1-baremetal` component repository. Its archive-backed `main` branch is the default; existing remote history remains on `master`, `m1`, and `stm31mp151faa`.

## Next Work

- Configure remotes/upstreams for M1TFC, Operator UI, and tfcroncli, then push their local commits.
- Finish `tfcroncli` clean snap build under Node 24.
- Add or plan snap packaging for `m1-cloud-client`.
- Add release manifests for expected snap and firmware versions.
- Add installed-state tooling for snap metadata and hardware-read firmware versions.
- Add fixture PC install and recovery documentation.
- Clean up Mercury firmware rough edges: malformed extra commas in `help` output and suspicious `65525` pin in `getalldata`.
- Decide whether to surface calibration save failures in `components/m1tfc/utils/config.js` instead of silently ignoring them.
- Re-test ICT calibration through REST after sudo command runner is deployed/restarted in the intended service mode.