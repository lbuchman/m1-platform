# M1 Platform Product Engineering Instructions

## Scope

This repository is a coupled hardware, firmware, and software manufacturing-test platform.
Treat requests as product-integration work, not software-only tasks.

Firmware and software are intentionally co-located because they share:
- protocol/message contracts
- runtime configuration formats
- state/data structures
- version compatibility constraints
- failure/recovery behavior
- release and deployment dependencies

Current component inventory (verify before edits if directories change):
- components/acm-testboard-fw
- components/m1-fixture-agent
- components/m1-operator-ui
- components/m1-rest-server
- components/m1testBoardFw
- components/m1tfc
- components/stm32mp1-baremetal

## Operator Control Protocol (Fail-Closed)

In ANALYSIS-ONLY mode:
- No tools.
- No terminal commands.
- No file edits.
- No tests/builds.
- No git actions.
- Allowed output is analysis only: problem framing, assumptions, risks, options, and proposed plans.

Permission model:
- No implied permission from context.
- If scope is ambiguous, ask exactly one clarifying question.
- For missing information, ask one clarifying question instead of taking action.

Execution unlock token:
- Required format: go: <one exact action>
- Execute exactly one authorized action.
- Auto-return to ANALYSIS-ONLY immediately after that action.
- If any additional action is needed, stop and request a new go token.

Pre-action gate:
- Before each executable action, restate the exact intended action (files and commands) and wait for explicit go.
- Execute only the approved list, nothing extra.

Immediate halt rule:
- STOP means stop immediately.
- After STOP, perform no further actions until a new explicit GO token is provided.

Violation tripwire:
- If any forbidden or unapproved action occurs, stop immediately and report:
- attempted action
- touched files/commands
- rollback options

Test-contract-first gate:
- Do not implement tests or code before the test contract is approved.
- Required contract fields:
1. Problem statement
2. Behavior under test
3. Stimulus path
4. Observable outputs
5. Pass/fail oracle
6. Excluded scope
7. Risks/dependencies
- Wait for explicit GO before implementation.

Micro-step approval flow:
1. GO-1: read-only discovery
2. GO-2: exact edits
3. GO-3: exact test/build commands
4. GO-4: stage/commit/push (only if requested)

## Required Reasoning

Before proposing or applying a change:

1. Identify affected layers:
- electrical hardware
- embedded firmware
- host or cloud software
- communication protocols
- manufacturing/test operations
- deployment/upgrade/recovery

2. Trace interface boundaries:
- command/response contracts
- config fields
- error codes
- timing/retry assumptions
- version expectations

3. Preserve compatibility unless a breaking change is explicitly requested.

4. Avoid local optimization that creates system-level regressions.

## Response Method

When presenting analysis or plans, separate:
- Confirmed facts
- Working interpretations
- Proposed changes
- Risks/dependencies
- Open questions

For uncertain bench behavior, prefer:
1. Observed fact
2. Mechanism
3. Consequence
4. Surviving conclusion

## Version and State Authority

- Actual software version authority: installed snap metadata.
- Expected software version authority: current manifest/build outputs.
- Actual firmware version authority: hardware query paths (for example via m1tfc command results).
- Do not claim installed state from source commit or manifest alone.

## Runtime and Calibration Safety

Active runtime paths:
- /etc/m1platform/config.json
- /etc/m1platform/calibration.json

Portable AI runtime snapshot paths:
- AI/runtime/config.json
- AI/runtime/calibration.json
- AI/runtime/MANIFEST.txt
- AI/runtime/SHA256SUMS

Snapshot workflow scripts:
- AI/capture-platform-state.sh
- AI/apply-platform-state.sh
- AI/verify-platform-state.sh

Data-handling constraints:
- Never print or commit raw secrets/tokens/passwords.
- Never print or commit raw calibration values.
- Use key/schema-level metadata when discussing runtime files.

Known calibration metadata (safe to use):
- calibration snapshot root key: boards
- boards contains 20 board slots
- slot schema is uniform across all 20 slots
- each slot sections: testPointsMnp(10), testPointsM1(9), ribbonCableA2DPins(4), strikeReg(2), ddrVoltageM1(3), ddrVoltageMnp(3), coinCellBattery(4)

## Build, Publish, Install Flow

Default release flow:
1. scripts/check-dirty-components.sh
2. scripts/build.sh
3. scripts/publish-fw.sh
4. allow m1-fixture-agent poll cycle or restart agent to force immediate install

When validating build/release changes:
- run real compile/build/test steps
- report warnings and errors introduced by the change
- do not treat editor-only diagnostics as compile validation

## Protected/Generated Areas

- Do not edit generated Snapcraft paths: parts/, prime/, stage/, *.snap.
- Do not change STM32MP1 bare-metal source/build behavior unless explicitly requested.
- Preserve known fixture sequencing/timing behavior unless bench evidence requires change.

## Diagram and Fixture Context

For fixture mechanics, power flow, PoE routing, and operation sequencing, use:
- doc/Architecture/Platform/Source-Diagrams/mnplus_design_review_v3.drawio

When updating or interpreting diagram-linked behavior:
- keep electrical vs operational statements distinct
- preserve explicit source-to-destination direction labels
- mark assumptions explicitly as assumptions

For continuation work, explicitly check whether each of these is covered:
- relay/control ownership and control-signal path
- measurement/observation points
- pass/fail and fault indication path
- safety/interlock behavior notes
- connector/pin-map summary tied to diagram blocks
