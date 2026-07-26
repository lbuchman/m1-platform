V# AI Notes

This directory stores repo-owned AI context for the M1 platform. Use these files to continue work across machines, models, and sessions without rediscovering platform facts.

Do not store secrets, private keys, cloud tokens, raw config contents, or raw calibration values in this directory.

## Files

| File | Use |
| --- | --- |
| `state.md` | Current durable platform state: components, version authority, runtime paths, build state, and current target |
| `metadata.md` | Stable repo metadata: paths, component locations, tools, runtime paths, and protected areas |
| `journal.md` | Chronological work log and next work items |
| `calibration.md` | AI working rules for this repo: diagnostic style, platform frame, quality target, and constraints |
| `capture-platform-state.sh` | Export active runtime config and calibration from `/etc/m1platform` into `AI/runtime/` |
| `apply-platform-state.sh` | AI-only apply: validate and report snapshot content without writing host runtime files |
| `verify-platform-state.sh` | Verify AI context file presence and snapshot integrity within `AI/runtime/` only |
| `runtime/` | Portable runtime snapshot folder for cross-PC restore |

## How To Use

At the start of a new AI session:

1. Read `AI/README.md`.
2. Read `AI/state.md` for current platform state.
3. Read `AI/metadata.md` for paths and repo structure.
4. Read the latest entries in `AI/journal.md` for what changed recently.
5. Read `AI/calibration.md` before making decisions that affect build, release, hardware, firmware, production, or recovery behavior.
6. If the task involves fixture electrical/mechanical behavior, read `doc/Architecture/Platform/Source-Diagrams/mnplus_design_review_v3.drawio` before answering.
7. For diagram-continuation work, read `AI/state.md` section "Diagram Continuation Contract" and satisfy its "Not yet captured" list explicitly.

For cross-PC AI-state transfer:

1. On source PC, run `AI/capture-platform-state.sh`.
2. Copy the full `AI/` folder to the target PC.
3. On target PC, run `AI/apply-platform-state.sh`.
4. On target PC, run `AI/verify-platform-state.sh`.
5. Confirm the verify script reports snapshot integrity and AI context checks as passed.

When work changes the platform state:

- Update `state.md` for durable facts that remain true after the session.
- Update `metadata.md` for stable paths, component names, tools, or protected areas.
- Update `journal.md` with concise dated entries for completed work and next steps.
- Update `calibration.md` only when the repo working rules or decision style need to change.

## Boundaries

- Keep root-level platform facts here.
- Keep detailed component behavior in the component repo README or docs.
- Keep entries short and factual.
- Separate observed facts from inference.
- Prefer references to file paths over copying large file contents.
- Never copy raw secrets, raw runtime config, or raw calibration data into AI notes.

Portable runtime snapshots in `AI/runtime/` are for AI context continuity and integrity checks. In AI-only mode, restore tooling must not mutate host runtime files.