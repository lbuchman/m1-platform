# fixtureFWSW

Contents of a test fixture's `fixtureFWSW/` directory in the
`m1mnplus-testing-platform` container:

- Fixture PC software
- Fixture's custom test-board firmware
- Target baremetal firmware

## Manifest file

A `manifestFile.json` shall be created describing the files below, with
each entry containing `filetype`, `filename`, and a SHA-512 `hash`.

```json
{
  "files": [
    {
      "filetype": "gui-react-snap",
      "filename": "gui-react_<version>_amd64.snap",
      "hash": "<sha-512 hash>"
    },
    {
      "filetype": "m1client-snap",
      "filename": "m1client_<version>_amd64.snap",
      "hash": "<sha-512 hash>"
    },
    {
      "filetype": "m1tfc-snap",
      "filename": "m1tfc_<version>_amd64.snap",
      "hash": "<sha-512 hash>"
    },
    {
      "filetype": "m1tfc-rest-snap",
      "filename": "m1tfc-rest-server_<version>_amd64.snap",
      "hash": "<sha-512 hash>"
    },
    {
      "filetype": "cloud-update-snap",
      "filename": "cloud-update-snap.snap",
      "hash": "<sha-512 hash>"
    },
    {
      "filetype": "m1testboardfw",
      "filename": "firmware.hex",
      "hash": "<sha-512 hash>"
    },
    {
      "filetype": "mercury-test-board-boardfw",
      "filename": "acmfirmware.hex",
      "hash": "<sha-512 hash>"
    },
    {
      "filetype": "stm32baremetalfw",
      "filename": "fsbl.stm32",
      "hash": "<sha-512 hash>"
    }
  ]
}
```

## File list

Fixture PC software:

- `gui-react-snap` — operator UI snap (`gui-react_<version>_amd64.snap`)
- `m1client-snap` — fixture cloud-update/CLI client snap, built from
  `tfcroncli` (`m1client_<version>_amd64.snap`)
- `m1tfc-snap` — test fixture controller snap (`m1tfc_<version>_amd64.snap`)
- `m1tfc-rest-snap` — REST server snap, built from `m1-rest-server`
  (`m1tfc-rest-server_<version>_amd64.snap`)
- `cloud-update-snap` — cloud update snap (`cloud-update-snap.snap`)

Fixture's custom test-board firmware:

- `m1testboardfw` — M1 test board (Teensy 4.1) firmware, built from
  `m1testBoardFw` (`firmware.hex`)
- `mercury-test-board-boardfw` — Mercury test board firmware, built from
  `mercury-testboard-fw` (`acmfirmware.hex`)

Target baremetal firmware:

- `stm32baremetalfw` — STM32MP1 ICT FSBL, built from
  `stm32mp1-baremetal` (`fsbl.stm32`)

## Directory contents

All of the files above, plus `manifestFile.json` describing them, shall
be placed directly in `fixtureFWSW/`.

Updating these files on a fixture is automatic — see
[`uploadSWFWtoCloud.md`](uploadSWFWtoCloud.md).
