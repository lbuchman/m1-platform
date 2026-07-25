# Fast Smoke Test Checklist

Use this checklist after snap install or before release tagging.

## Preconditions

- Fixture host booted and snaps installed.
- Test board connected on expected USB/serial path.
- No stale serial monitor holding `/dev/ttyACM0`.

Quick lock check:

```bash
lsof /dev/ttyACM0
```

If locked by a monitor process, stop it before continuing.

## 1) REST Command Routing Smoke

Goal: verify REST routes commands to `m1tfc`.

```bash
curl -sS -X POST http://127.0.0.1:3300/command \
  -H 'Content-Type: application/json' \
  -d '{"command":"power","argument":"--state off"}'
```

Expected:

- JSON response with `"status":"OK"`.
- No `Unsupported command` error.

## 2) Board Identity Smoke

Goal: verify board ID path from firmware through REST config.

```bash
curl -sS http://127.0.0.1:3300/config | jq '.boardId, .fwVersion, .machineName'
```

Expected:

- `boardId` is populated (not `unknown`) when serial port is free.

## 3) UI Serial Workflow Smoke

Goal: verify operator serial guard behavior.

1. Enter valid 10-digit serial in UI.
2. Start `COMMISSION` or `RE-TEST`.
3. Confirm serial input is invalidated/locked while sequence uses captured serial.
4. Double-click serial field.
5. Confirm last invalidated serial value is restored.

Expected:

- Serial field locks after run start.
- Double-click restores previous serial value.

## 4) Calibration Argument Smoke

Goal: verify battery voltage prompt propagates into calibration runtime.

1. In debug mode, click `CALIBRATE`.
2. Enter measured battery voltage (for example `3.05`).
3. Observe command/log stream.

Expected:

- ICT calibration run starts.
- Runtime uses provided `--batteryVoltage` value.
- On success path, log/result indicates calibration completion.

## 5) Run Completion Message Smoke

Goal: verify success wording split.

Expected:

- Calibration success message: `Calibration Complete!!!`.
- Non-calibration ICT success message: `ICT Test Passed!!!`.

## 6) Basic Failure Path Smoke

Goal: verify failure surfacing is operator-visible.

1. Trigger a known safe failure condition (for example disconnected fixture signal for one step).
2. Run sequence.

Expected:

- UI shows failed status and step context.
- Failure summary lines appear in debug mode.

## Pass/Fail Gate

Pass only if all checks succeed without manual code edits between checks.
