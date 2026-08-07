---
description: Use when working in components/acm-testboard-fw on RS485 reader behavior, watchdog resets, or Teensy runtime loop diagnostics.
applyTo: components/acm-testboard-fw/**
---

## Current Confirmed Bench Facts

- Reader task has a 1 ms cadence and echoes incoming serial bytes immediately when available.
- Previously tested forcing RS485 termination enable did not resolve the self-sustaining retransmission behavior.
- Cable-length reflection timing was already ruled out as the primary cause for the observed 1 kHz pattern.
- Boot-time watchdog loop risk exists if long init steps run before regular watchdog servicing.

## Guardrails

- Do not reintroduce already disproven single-cause explanations without new bench evidence.
- Separate observed behavior from root-cause inference.
- When proposing fixes, include how to verify on bench (scope/serial/log evidence).
- Keep changes minimal and reversible until bench validation confirms mechanism.

## Validation Expectations

For each proposed fix, define:
1. expected observable change
2. measurement point or command output to confirm
3. rollback criteria if behavior worsens
