---
description: Use when modifying components that cross firmware/software/runtime boundaries (m1tfc, m1-rest-server, m1-operator-ui, m1-fixture-agent) or when changing manifests, build, publish, install, or version reporting behavior.
applyTo: components/**
---

## Integration Contract

- Treat command APIs and runtime files as cross-component contracts.
- If a field/option/command changes on one side, verify the other side in the same change scope.
- Do not silently change externally visible behavior.

## Runtime Contract

Runtime source-of-truth files:
- /etc/m1platform/config.json
- /etc/m1platform/calibration.json
- /var/m1mtf/

Config keys that are operationally relevant (names only):
- tfInterface, vendorSite, productName, fwDir, mtfDir, programmingCommand
- skipBatteryTest, skipRS485test, skipTestpointCheck
- coinCellMinVoltageNew, coinCellMinVoltageUsed

Sensitive config keys (never print values):
- conString
- productionPassword
- debugPassword

Calibration metadata (safe schema-level facts):
- root object key: boards
- boards slot count: 20
- uniform slot schema across slots

## Version Reporting Contract

- UI should show distinct values for UI app, REST server, m1tfc, and m1-fixture-agent.
- REST /config should expose explicit version fields for each displayed component.
- Use installed snap metadata for actual installed versions.

## Build and Publish Contract

- Build from clean component repositories for full production-style version stamping.
- Publish artifacts and manifest together; do not publish partial sets.
- After publish, trigger fixture-agent polling/restart if immediate install is needed.

## Validation Expectations

After editing integration paths:
1. component tests
2. component build/lint where applicable
3. end-to-end version/install verification through manifest + installed snap list
