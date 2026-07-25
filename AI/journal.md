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

- Added `doc/operator-ui-user-guide.md`: operator workflow for the React test panel, including the existing `ui.png` reference image, production/debug mode behavior, run/re-test behavior, failure handling, debug controls, log behavior, and REST interfaces.
- Added `doc/pictures/m1-fixture-and-mercury-test-architecture.svg`: software integration diagram covering React Operator UI, REST server, M1TFC, runtime files, Mercury TCP/UDP terminal access, and scheduled `tfcroncli`. The diagram explicitly labels documented communication interfaces and excludes fixture wiring/UUT hardware.
- Confirmed `components/stm32mp1-baremetal` as a standalone local firmware repository imported from `M1Combined`; generated build output is excluded from the import.
- Documented its ICT purpose: SDRAM is the test subject, so the STM32MP1 target must run bare-metal rather than Linux during SDRAM ICT.
- Documented Arm GNU Toolchain `12.2.MPACBTI-Rel1` at `/opt/arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi` as the STM32MP1 bare-metal component-only compiler toolchain.
- Reduced `bootloaders/mp1-boot` to the active FSBL path: removed unused U-Boot-derived DDR tuning/test sources, an unused CPU port source, formatter/editor/build debris, and replaced upstream tutorial documentation with the M1 ICT FSBL contract.
- Recovered the `STRIKE2_KICKER_POWER` board symbol from original monorepo history: it had been renamed to `STRIKE1_KICKER_POWER` by `59b8cfc1`, producing a duplicate and breaking clean builds. Restored its prior `GPIO::H` pin `3` assignment; clean FSBL build now produces `build/fsbl.stm32` (43,288 bytes).
- Moved the active STM32MP1 FSBL closure from `bootloaders/mp1-boot` into root `src/`, `include/`, `tools/`, `linker.ld`, and `Makefile`; root `source env.sh && make clean && make` produces `build/fsbl.stm32` (43,280 bytes). Removed obsolete prebuilt U-Boot images and the legacy nested MP1-Boot path.
- Added `READMEConfig.md` documenting fixture configuration and calibration behavior.
- Updated M1TFC calibration seed handling to fill incomplete profiles from defaults while retaining populated persisted data; added focused Jest coverage.
- Changed M1TFC label printing to use unique temporary staging directories and cleanup; added focused Jest coverage.
- Preserved asynchronous STM32CubeProgrammer launch and fixed fixture delays after confirming programmer teardown must not control ICT timing.
- Updated operator UI log behavior: production shows failures, debug shows full logs, clear calls the backend, and failed runs show a debug summary.
- Added Snapcraft artifact ignores and removed tracked Snap packages across the root and component repositories.
- Resolved M1TFC ESLint findings without changing ordered hardware/retry execution; `npm run lint` passes.
- Committed and pushed root platform `160b07b` and REST server `a5459e7`; committed M1TFC `70e221c`, Operator UI `64916a4`, and tfcroncli `543ac5b` locally.
- Published the private `lbuchman/stm32mp1-baremetal` component repository. Its archive-backed `main` branch is the default; existing remote history remains on `master`, `m1`, and `stm31mp151faa`.

## 2026-07-20

- Confirmed user-reported baseline: `components/m1testBoardFw` CMake firmware flow is working.
- Added PlatformIO configuration at `components/m1testBoardFw/platformio.ini` for Teensy 4.1 (`teensy41`) to preserve existing source layout and compile-time behavior.
- Added `components/m1testBoardFw/README.platformio.md` documenting PlatformIO build and USB upload usage.
- Kept legacy CMake build files intact; migration did not remove or rewrite the existing CMake path.
- Explicitly excluded `program.sh` integration from PlatformIO upload flow per user request.
- Removed host-specific Arduino IDE library path from `components/m1testBoardFw/platformio.ini`; PlatformIO now relies on its own Teensy framework packages plus local project `libs/`.

## 2026-07-24

- Added fixture system diagram document at `doc/design-doc/system-diagrams/mnplus-fixture-electrical-operation-diagram.md` for cross-session and cross-PC recovery.
- Diagram scope currently captures fixture mechanics, primary power, interface ports, and PoE-to-UUT routing.
- Mechanical path documented: hinged cover closes, mounting hardware aligns board, board is pressed onto pogo-pin bed, and UUT test-point contact is secured by controlled closure force.
- Primary power path documented: back-panel `120V AC` input -> back-panel main switch -> internal main PSU -> `12V DC` and `5V DC` rails.
- Added interface ports on back panel: Ethernet jack and USB-B standard jack.
- Added internal interface routing: USB-B jack -> USB switch; Ethernet jack -> SAM-E 3-port Ethernet switch.
- Added secondary power path for PoE: switched `120V AC` -> `120V/48V DC` PSU -> relay -> Ethernet power injector power input.
- Corrected PoE data and output routing per bench description: SAM-E switch Ethernet output feeds PoE injector Ethernet input; PoE injector output goes to UUT through pogo-pin connections.
- Updated operation sequence diagram to include relay-enable and PoE feed readiness before declaring fixture ready for test steps.
- Captured fixture contact-quality guidance for future mechanical refinement: use fixed hard-stop compression, repeatable alignment datum, distributed hold-down, and repeatable-latch closure to stabilize pogo contact resistance.
- Captured remote access troubleshooting state: `ssh mnptestf5` success with WinSCP "host not found" is most likely alias-resolution mismatch where OpenSSH `Host` alias works in CLI but WinSCP resolves literal host name unless OpenSSH config is imported or equivalent site is created manually.
- Captured WinSCP restore action for other PCs: import from OpenSSH config in Login/New Session window when available, otherwise use resolved values from `ssh -G mnptestf5` (hostname, user, port, key file) to create a saved site.
- Added `AI/capture-platform-state.sh` to export current `/etc/m1platform/config.json` and `/etc/m1platform/calibration.json` into `AI/runtime/`.
- Added `AI/apply-platform-state.sh` to restore `AI/runtime/config.json` and `AI/runtime/calibration.json` into `/etc/m1platform/` on another trusted PC.
- Added integrity and provenance artifacts during capture: `AI/runtime/SHA256SUMS` and `AI/runtime/MANIFEST.txt`.
- Updated AI restore documentation so importing the full `AI/` directory can carry metadata, state, journal context, and runtime calibration/config state.
- Added `AI/verify-platform-state.sh` to validate complete AI context presence and confirm runtime config/calibration match after apply on another PC.
- Improved snapshot checksum portability by generating `AI/runtime/SHA256SUMS` with runtime-relative filenames.

## Next Work

- Validate the newly built STM32MP1 FSBL on the fixture target, including DDR/SDRAM ICT behavior.
- Configure remotes/upstreams for M1TFC, Operator UI, and tfcroncli, then push their local commits.
- Finish `tfcroncli` clean snap build under Node 24.
- Add or plan snap packaging for `m1-cloud-client`.
- Add release manifests for expected snap and firmware versions.
- Add installed-state tooling for snap metadata and hardware-read firmware versions.
- Add fixture PC install and recovery documentation.
- Clean up Mercury firmware rough edges: malformed extra commas in `help` output and suspicious `65525` pin in `getalldata`.
- Decide whether to surface calibration save failures in `components/m1tfc/utils/config.js` instead of silently ignoring them.
- Re-test ICT calibration through REST after sudo command runner is deployed/restarted in the intended service mode.