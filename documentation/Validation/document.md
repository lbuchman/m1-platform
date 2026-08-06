# React Commission Test Plan

## 1. Scope

This plan covers the end-to-end `COMMISSION` flow started from the React operator UI and executed through:

- `m1-operator-ui` -> `m1-rest-server` -> `m1tfc`
- Fixture firmware paths (`m1testBoardFw`, `acm-testboard-fw` where applicable)
- UUT interfaces used by each command

This document is intentionally code-grounded. Firmware runtime `help` remains the authoritative command/protocol reference.

## 2. Commission Entry Point (React)

`COMMISSION` button triggers `runSequence('commission')`.

Sequence order:

1. `ict`
2. `progmac`
3. `flash`
4. `functest`
5. `eeprom`
6. `pingM1apps`
7. `makelabel`

Behavior notes:

- UI serial must match `^\d{10}$`.
- In production mode, rerun of the same serial is blocked after a full pass.
- Commands are streamed through `POST /command/stream` and considered pass/fail by final `payload.result.status`.
- On first failed step (except `PRINT LABEL`), UI attempts `makelabel --error`.
- `cleanup` is invoked at sequence end on success, and also on failure except precheck hardware failure (error code `15`).

## 3. Preconditions

1. React UI reachable and unlocked for run mode.
2. REST service healthy (`GET /health` = `status: OK`).
3. `m1tfc` command queue available (no stuck command).
4. Required devices present for ICT precheck (unless debug level 2):
- `/dev/ttyACM0` (test board)
- `/dev/ttyUSB0` (UUT terminal converter)
5. Network prerequisites for ICT precheck:
- `tfInterface` exists (default `eth1`)
- Interface at `192.168.0.100` present (UUT ethernet check)
6. If label printing enabled, printer detect path must pass (`lsusb | grep QL-810W`).

## 4. Command-Level Acceptance Criteria

## 4.1 ICT (`ict`)

Commission invocation from UI adds:

- `--cellBatTol used` when running in Debug mode (`isDebug`), otherwise `new` in production commission mode
- `--debug <level>` and `--serial <10-digit>`

Pass criteria:

1. ICT command returns normal exit.
2. Log contains `ICT Test Passed!!!`.
3. DB ICT status is updated to pass.

Fail criteria:

1. Any subtest failure sets command failure (`ictTestFailed`).
2. Log contains `One or more tests Failed!!!` or explicit exception.

ICT coverage includes (depending on product/config):

- Lever lock check
- Voltage/test-point checks
- DDR voltage and DDR3 test
- Ribbon cable tests
- RS-485 tests (plus MNP reader RS-485 on MNPlus)
- Status LED and tamper tests
- EEPROM checks
- Coin-cell battery threshold check (`new` or `used` profile)
- MNPlus-specific functional set and PoE switch-over check

## 4.2 Program MAC (`progmac`)

Pass criteria:

1. `run()` completes without error.
2. `runProgSecret()` completes without error.
3. Command exits normal.
4. Accepted production case: OTP and/or secret key already programmed (informational, not a failure).

Fail criteria:

- Any exception or non-normal exit.

## 4.3 Flash (`flash`)

Pass criteria:

1. If `progEmmc` enabled: flash routine completes and exits normal.
2. Cleanup power-down path completes (`testEndSuccess`).

Fail criteria:

- Flash routine non-zero exit code.

## 4.4 Functional Test (`functest`)

Observed functional subtests executed by `FuncTest.run()`:

1. OTP MAC presence check:
- Reads MAC from OTP and fails if empty/zero (`00:00:00:00:00:00`).
2. UUT boot and login path:
- Powers target, waits for login prompt, logs in, initializes test mode.
3. Network/SSH access:
- Connects to target over SSH using runtime IP.
4. MAC consistency check:
- Verifies `ip link show eth0` MAC matches OTP MAC.
5. I2C bus connectivity:
- On MNPlus (`activeBus=0`): checks I2C bus 0 pattern.
- On M1 (`activeBus=1`): checks I2C bus 1 pattern, plus additional bus 0/2 pattern check.
6. Watchdog reboot test:
- Arms watchdog, expects reboot, reconnects after reboot.
7. SPI RAM retention test:
- Writes random block to SPI RAM mirror, reboots, verifies persisted content by `diff`.
8. USB host pen-drive mount test:
- Verifies `/dev/sda` mount presence (unless `skipUSBPenDriveTest` is enabled).
9. RTC synchronization and persistence:
- Sets system/hwclock from PC time, power-cycles, then verifies RTC delta is within 5 seconds.
10. Functional completion flag:
- Creates `/home/s2user/testpassed` and updates DB functional-test status.

Pass criteria:

1. Command exits normal (`exitCodes.normalExit`).
2. Log contains `Functional test passed`.
3. `common.testEndSuccess()` path executes.

Fail criteria:

1. Any exception in subtests.
2. Non-normal exit (`exitCodes.functTestFailed` or command failure path).
3. Error-to-code mapping is recorded for known failure modes (RTC, WDT, USB pen drive, MAC compare, terminal/ether/SSH reconnect, DFU, OTP MAC missing).

## 4.5 EEPROM (`eeprom`)

Pass criteria:

1. `vendorSite` is configured.
2. EEPROM programming flow completes without error.
3. Cleanup power-down path completes (`testEndSuccess`).
4. Accepted production case: EEPROM not blank warning is acceptable when verify phase reports valid EEPROM data.

Fail criteria:

- Missing `vendorSite`, programming failure, or non-normal exit.

## 4.6 App Port Check (`pingM1apps`)

Pass criteria:

1. Boot mode is set to runtime and power cycle completes.
2. TCP port 80 on `m1defaultIP` opens within retry window.
3. Command exits normal.

Retry window:

- 30 retries
- 5 seconds delay between retries
- Approximate timeout: 150 seconds

Fail criteria:

- Port 80 does not open within window.

## 4.7 Label Print (`makelabel`)

Pass criteria (normal path):

1. MAC read from OTP is valid and non-zero.
2. EEPROM serial matches run serial.
3. Label print call succeeds.

Pass criteria (error path):

- `--error` label prints with DB error code context.

Fail criteria:

- MAC read invalid, EEPROM mismatch, printer failure, or command failure.

## 5. Tolerances and Thresholds (Code Defaults)

These are default values from `m1tfc` command/runtime config and regulator logic.

1. General voltage tolerance: `0.05` (5%), unless per-test-point override is present.
2. Lever lock voltage tolerance: absolute `0.2` around expected level.
3. Coin-cell minimum voltage:
- `new`: `3.0 V`
- `used`: `2.9 V`
4. Commission `cellBatTol` is mode-dependent in React:
- Debug mode commission: `used`
- Production-mode commission: `new`

Important:

- Per-point tolerance can override the global 5% tolerance in calibration data.
- Runtime config can override defaults (`coinCellMinVoltageNew`, `coinCellMinVoltageUsed`, `tolerance`, etc.).

## 5.1 Test Points Specification

Authoritative source in code/runtime:

- `components/m1tfc/tests/calibrationDefault.js` (default test-point definitions)
- `/etc/m1platform/calibration.json` (board-specific overrides)
- `components/m1tfc/tests/regulators.js` and `components/m1tfc/utils/voltageHelper.js` (pass/fail evaluation)

Default M1 test points (`testPointsM1`):

- `TP025` expected `5.0 V`
- `TP33` expected `2.8 V`
- `TP35` expected `3.3 V`
- `TP34` expected `3.3 V`
- `TP36` expected `1.2 V`
- `J5.13` expected `11.7 V`
- `J5.5` expected `6.0 V`
- `J5.7` expected `6.0 V`
- `J5.8` expected `6.0 V`

Default MNPlus test points (`testPointsMnp`):

- `TP204` expected `5.0 V`
- `TP308` expected `2.8 V`
- `TP303` expected `1.2 V`
- `TP305` expected `3.3 V`
- `TP306` expected `3.3 V`
- `TP401` expected `5.0 V`
- `TP2301` expected `12.8 V`
- `TP202` expected `12.0 V`
- `J2101.1` expected `11.85 V`
- `J2001.1` expected `11.85 V`

Additional calibrated groups used by ICT:

- DDR voltage point:
	- M1: `TP31` expected `1.35 V`
	- MNPlus: `TP304` expected `1.35 V`
- Strike regulator points (MNPlus path):
	- `SW1601.6` expected `28.0 V`
	- `SW1602.6` expected `28.0 V`
- Ribbon A/D reference points:
	- `TP1801`, `TP1802`, `TP1901`, `TP1902` expected `2.7 V`

Acceptance rule for each voltage test point:

1. Read raw value from test board firmware (`getiopin`).
2. Apply point scale.
3. Compute error as `abs(measured_scaled - expected) / expected`.
4. Compare to tolerance:
- Use point-specific tolerance when defined in calibration data.
- Otherwise use global runtime tolerance (default `0.05`).
5. Pass when error is less than or equal to tolerance.
6. Fail when error exceeds tolerance; error code is recorded and ICT fails.

Calibration behavior:

- In calibration mode, failing points do not auto-pass; operator must adjust/calibrate and rerun.
- Updated scale/threshold data is persisted to `/etc/m1platform/calibration.json` for that board ID.

## 6. End-to-End Commission Acceptance

A board is accepted as `COMMISSION PASS` only if all of the following are true:

1. All seven commands in sequence return pass.
2. No step is stopped or aborted.
3. Final UI result is pass.
4. `cleanup` runs after sequence success.
5. In production mode, serial is latched as passed (prevents immediate duplicate rerun).

A board is `COMMISSION FAIL` if any step fails or is stopped.

## 6.1 Log-Matched Baseline (2026-07-25 Reference Run)

The supplied run log is consistent with this plan and is treated as a known-good baseline for MNPlus commission behavior:

1. Commission started with stream command equivalent to:
`sudo -n m1tfc ict --serial <serial> --debug 1 --cellBatTol used`
2. `ict` passed with `ICT Test Passed!!!` after the following observed checks:
`TP204`, `TP308`, `TP303`, `TP305`, `TP306`, `TP401`, `TP2301`, `TP202`, `J2101.1`, `J2001.1` test-point checks
coin-cell check using `used` battery profile
strike regulator checks (`SW1601.6`, `SW1602.6`)
DDR voltage check (`TP304`)
ribbon A/D checks (`TP1801`, `TP1802`, `TP1901`, `TP1902`)
RS485 checks (including reader RS485 on MNPlus)
status LED and tamper checks
DDR3 check
EEPROM check
PoE switch-over check
3. `progmac` completed as pass while logging already-programmed conditions (`OTP is not blank` and/or secret key already programmed), treated as accepted production state.
4. `flash` completed with `Target flashing is done`.
5. `functest` completed with `Functional test passed`.
6. `eeprom` logged `EEPROM not Blank` and still passed with `The EEPROM Data is valid`; this is an accepted state.
7. `pingM1apps` passed with runtime app reachability on port `80`.
8. `makelabel` executed in normal path.
9. `cleanup --serial <serial>` executed at run end.

## 7. Suggested Execution Record

For each run, record:

1. Serial number
2. Product (`m1-3200` or `mnplus`)
3. Debug level used
4. Effective tolerance values (`tolerance`, coin-cell thresholds)
5. Step reached at failure (if any)
6. Error code(s) printed/logged
7. Whether error label printed successfully
8. Operator, date/time, fixture ID

## 8. Code Trace Points

Primary implementation files:

- `components/m1-operator-ui/src/App.jsx`
- `components/m1-operator-ui/src/constants.js`
- `components/m1-rest-server/src/server.js`
- `components/m1-rest-server/src/commandRunner.js`
- `components/m1tfc/bin/commands/ict.js`
- `components/m1tfc/tests/ictTestRunner.js`
- `components/m1tfc/tests/regulators.js`
- `components/m1tfc/bin/commandSupport.js`
- `components/m1tfc/bin/commands/flash.js`
- `components/m1tfc/bin/commands/progmac.js`
- `components/m1tfc/bin/commands/functest.js`
- `components/m1tfc/bin/commands/eeprom.js`
- `components/m1tfc/bin/commands/pingM1apps.js`
- `components/m1tfc/bin/commands/makelabel.js`
