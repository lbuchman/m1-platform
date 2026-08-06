# productFW

Contents of a test fixture's `productFW/` directory in the
`m1mnplus-testing-platform` container:

- Production firmware for the M1-3200 product
- Production firmware for the MNPlus product

## Source and packaging

- Firmware shall be retrieved from the LenelS2 Artifactory.
- Firmware shall be recompressed as a `.txz` archive.
- At the root of the archive there shall be a `VERSION` file containing a
  single line, which defines the released version.

## Manifest file

A `manifestFile.json` shall be created describing the firmware archives.
Each entry contains:

- `filetype` — identifies the firmware (e.g. `m1firmware`, `mnpfirmware`)
- `filename` — the file's name
- `hash` — SHA-512 hash of the file, used to verify the download

```json
{
  "files": [
    {
      "filetype": "m1firmware",
      "filename": "m1firmware.txz",
      "hash": "<sha-512 hash>"
    },
    {
      "filetype": "mnpfirmware",
      "filename": "mnpfirmware.txz",
      "hash": "<sha-512 hash>"
    }
  ]
}
```

## Directory contents

All three files shall be placed directly in `productFW/`:

- `m1firmware.txz` — M1-3200 production firmware
- `mnpfirmware.txz` — MNPlus production firmware
- `manifestFile.json` — the manifest describing the two archives above

Updating these files on a fixture is automatic — see
[`uploadSWFWtoCloud.md`](uploadSWFWtoCloud.md).

