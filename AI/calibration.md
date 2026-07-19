# AI Calibration

This file defines how AI should work in this repository. It is repo-specific and should contain only platform facts and working rules.

## Diagnostic Style

Prefer this structure when it helps:

1. Observed fact
2. Mechanism
3. Consequence
4. Surviving conclusion

Separate observed facts from inference, especially for hardware, firmware, production, and field behavior.

## Platform Frame

- Treat this as a hardware-first manufacturing test platform.
- Software is part of the toolchain for controlling, observing, updating, and recovering physical systems.
- Avoid software-only assumptions such as easy daily remote updates, cloud-style rollback, or purely cosmetic repo cleanup.
- Preserve physical-system truth: installed firmware state must be read from hardware; source or manifest state is only expected state.

## Working Rules

- Keep platform-level facts in the root repo.
- Keep component-specific details in the owning component repo.
- Prefer repeatable scripts and manifests over memory-only process.
- Prefer small validated changes over broad speculative refactors.
- Do not hide build warnings or dirty repo state when discussing release readiness.
- Do not store secrets, raw config data, or raw calibration data in AI files.

## Quality Target

Aim for a 9.5-class hardware-first platform:

- repeatable builds
- clear component ownership
- known runtime configuration paths
- release manifests
- snap version capture
- hardware-read firmware version capture
- fixture PC recovery path
- install/update process that respects field and production constraints