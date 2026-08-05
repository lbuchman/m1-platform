# SW/FW Integration Test Plan

## 1. Purpose

This document defines the integration test plan for the M1 fixture software and firmware stack:

- PC layer: m1-operator-ui, m1-rest-server, m1tfc
- Fixture firmware: m1testBoardFw, acm-testboard-fw
- UUT firmware/runtime path: stm32mp1-baremetal over serial and USB/DFU flow

The goal is to validate command routing, link ownership, protocol consistency, boot-mode control behavior, and operator-visible results.

## 2. Scope

In scope:

- End-to-end command flow from UI to hardware-facing links.
- JSON command/response behavior on all three firmware targets.
- Link separation and ownership by m1tfc.
- UUT mode selection flow and DFU programming path.
- Access-control path exercise through mercury-testboard-fw.
- Error handling and operator feedback.

Out of scope:

- Cloud/update paths (m1-cloud-client, tfcroncli).
- Long-term reliability/aging tests.
- EMI/EMC and environmental qualification.

## 3. References

- doc/Architecture/Software/sw-fw-dataflow-diagram.md
- doc/Validation/fast-smoke-test-checklist.md

## 4. Test Environment

Host:

- PC Ubuntu 26.04 server
- Required services installed and running: m1-rest-server, m1tfc, operator UI stack

Hardware:

- M1 Test Board running m1testBoardFw
- Mercury Test Board running acm-testboard-fw
- UUT with stm32mp1-baremetal and USB connection

Connectivity:

- Serial link A: m1tfc <-> m1testBoardFw
- Serial link B: m1tfc <-> UUT serial header (independent of link A)
- UDP link: m1tfc <-> acm-testboard-fw
- USB link: PC <-> UUT (DFU/SSD workflow)

Tooling:

- curl
- jq
- serial terminal/log capture utility
- packet capture for UDP verification (optional but recommended)

## 5. Entry and Exit Criteria

Entry criteria:

- Firmware versions loaded and recorded.
- Cabling and power verified.
- No process holds required serial ports.
- m1-rest-server health endpoint reachable.

Exit criteria:

- All P0 and P1 test cases pass.
- No unresolved critical defects.
- Failed/blocked cases documented with reproducible evidence.

## 6. Test Data

- At least one known-good UUT
- At least one known-fault-injection condition (safe, reversible)
- Operator serial numbers for commission/re-test flows
- Expected command/response samples for each target firmware

## 7. Test Cases

Priority legend:

- P0: release blocker
- P1: high priority
- P2: medium priority

### 7.1 Control-Plane and Routing

TC-CP-001 (P0) UI to REST command path

- Objective: verify UI submits commands and REST accepts them.
- Steps:
  1. Trigger a safe command from UI.
  2. Confirm REST endpoint receives the request.
- Expected:
  - HTTP success response.
  - Request payload preserved (command + arguments).

TC-CP-002 (P0) REST to m1tfc dispatch

- Objective: verify REST does not execute hardware logic itself.
- Steps:
  1. Send command through REST API.
  2. Check logs for forward/dispatch event to m1tfc.
- Expected:
  - m1tfc receives command.
  - REST layer reports status only, no hardware-side execution path.

### 7.2 Link Ownership and Separation

TC-LINK-001 (P0) Dual serial independence

- Objective: verify m1tfc owns two independent serial links.
- Steps:
  1. Open m1testBoardFw command session through m1tfc.
  2. In parallel, execute a UUT serial command through m1tfc.
- Expected:
  - Both links operate without cross-talk.
  - UUT serial path does not depend on M1 board passthrough.

TC-LINK-002 (P1) UDP channel availability

- Objective: verify m1tfc command path to acm-testboard-fw over UDP.
- Steps:
  1. Send a acm-testboard-fw-targeted command.
  2. Capture response and timing.
- Expected:
  - Response returns over UDP.
  - No fallback to serial for acm path.

### 7.3 Protocol Consistency

TC-PROTO-001 (P0) JSON response schema across all targets

- Objective: verify common command/response model.
- Steps:
  1. Send one valid command to each target firmware.
  2. Record responses.
- Expected:
  - Response is parseable JSON.
  - Includes status and error fields.
  - Optional data field present when applicable.

TC-PROTO-002 (P1) Invalid command behavior

- Objective: verify invalid command handling is deterministic.
- Steps:
  1. Send malformed/unknown command to each target.
- Expected:
  - Failure status returned.
  - Error message present and readable.
  - No crash or stuck link.

### 7.4 UUT Mode and Programming Flow

TC-BOOT-001 (P0) Boot-select GPIO control

- Objective: verify one GPIO control pin sets intended boot mode.
- Steps:
  1. Select normal boot mode.
  2. Select DFU mode.
  3. Select download-and-execute mode for stm32mp1-baremetal flow.
- Expected:
  - Hardware state transitions match selected mode.
  - Transitions are logged.

TC-BOOT-002 (P1) GPIO/A-D test-point measurement path

- Objective: verify GPIO/A-D channels are used for testing, not for download transport.
- Steps:
  1. Run test-point measurement routine.
  2. Run DFU download workflow.
- Expected:
  - Test-point reads return via test routines.
  - DFU transport occurs on USB path; no dependency on GPIO/A-D transport.

TC-DFU-001 (P0) USB/DFU programming path

- Objective: verify UUT programming over USB/DFU path.
- Steps:
  1. Set DFU mode.
  2. Perform DFU programming run.
- Expected:
  - Programming completes.
  - Post-program status indicates success.

### 7.5 Access-Control Path

TC-ACM-001 (P1) Mercury access I/O exercise

- Objective: verify access-control hardware exercise path.
- Steps:
  1. Execute mercury test routine targeting access-control I/O.
- Expected:
  - Command reaches mercury-testboard-fw over UDP.
  - Expected access-control activity/telemetry observed.

### 7.6 Operator Experience and Results

TC-UI-001 (P1) Run-state guard behavior

- Objective: verify serial/operator input guard behavior during execution.
- Steps:
  1. Start a run from UI.
  2. Attempt to edit serial fields during active run.
- Expected:
  - UI enforces run-state lock behavior as designed.

TC-UI-002 (P1) Success/failure messaging

- Objective: verify clear completion and failure signaling.
- Steps:
  1. Run one successful test sequence.
  2. Trigger one safe controlled failure.
- Expected:
  - Success and failure states are clearly distinguishable.
  - Failure output includes actionable context.

## 8. Negative and Recovery Tests

TC-NEG-001 (P0) Serial port unavailable

- Expected:
  - System reports port busy/unavailable clearly.
  - No deadlock; retry path is available.

TC-NEG-002 (P1) UDP timeout/retry

- Expected:
  - Retry or timeout behavior follows design.
  - Error surfaced to operator/logs.

TC-REC-001 (P1) Recover after transient link loss

- Expected:
  - Operator can recover without process restart when possible.
  - Recovery procedure documented in logs.

## 9. Traceability Matrix (Minimum)

- Requirement: UI command routing -> TC-CP-001, TC-CP-002
- Requirement: m1tfc sole link owner -> TC-LINK-001, TC-LINK-002
- Requirement: common JSON protocol -> TC-PROTO-001, TC-PROTO-002
- Requirement: boot-mode control by GPIO pin -> TC-BOOT-001
- Requirement: GPIO/A-D used for testing -> TC-BOOT-002
- Requirement: USB/DFU programming path -> TC-DFU-001
- Requirement: mercury access-control over UDP -> TC-ACM-001

## 10. Reporting

For each test case record:

- Test ID
- Build/firmware versions
- Date/time
- Pass/Fail/Blocked
- Evidence (logs, command output, captures)
- Defect ID (if failed)

## 11. Sign-off

Approval requires:

- QA/Test owner sign-off
- Firmware owner sign-off
- System/Fixture owner sign-off

Release recommendation: only after all P0 tests pass and no open critical defects remain.
