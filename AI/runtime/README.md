# Runtime Snapshot Folder

This folder stores portable runtime-state snapshots used to restore platform state on another PC.

Expected files:

- `config.json`
- `calibration.json`
- `MANIFEST.txt`
- `SHA256SUMS`

Typical workflow:

1. On source PC, run `AI/capture-platform-state.sh`.
2. Copy the full `AI/` folder to target PC.
3. On target PC, run `AI/apply-platform-state.sh`.

Note:

- These files can contain production runtime settings and calibration values.
- Handle and transfer this folder as controlled engineering data.
