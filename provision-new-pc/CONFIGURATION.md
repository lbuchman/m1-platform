# M1 Platform Configuration

This document describes the host configuration consumed by `m1tfc` when it runs from VS Code, a terminal, or the React launcher.

## Configuration Files

`m1tfc` reads these host files:

```text
/etc/m1platform/config.json
/etc/m1platform/calibration.json
```

The effective configuration is built in this order:

1. Built-in `m1tfc` defaults.
2. `/etc/m1platform/config.json`.
3. `/etc/m1platform/calibration.json`.

Later files override or extend earlier values. Both files must contain valid JSON. If either file is missing or unreadable, `m1tfc` continues with the remaining configuration.

## Shared Fixture Files

Store fixture firmware, image directories, and test logs at:

```text
/var/m1mtf
```

The ICT SRAM image is normally:

```text
/var/m1mtf/fsbl.stm32
```

`/var/m1mtf` is intentionally independent of the invoking user. This matters because the React application runs `m1tfc` with `sudo`; a `$HOME/m1mtf` default would otherwise resolve to `/root/m1mtf` instead of the fixture data directory.

## config.json

`config.json` holds machine and production-test settings. The following non-secret settings are required for a configured fixture:

```json
{
  "tfInterface": "enp1s0",
  "vendorSite": "s5",
  "skipBatteryTest": false,
  "coinCellMinVoltageNew": 3.0,
  "coinCellMinVoltageUsed": 2.9,
  "skipTestpointCheck": false,
  "skipRS485test": false,
  "productName": "mnplus",
  "forceEppromOverwrite": false,
  "fwDir": "stm32mp15-lenels2-mnp",
  "layoutFilePath": "flashlayout_st-ls2m1c-image-core/optee/FlashLayout_emmc_stm32mp151f-ls2m1c-optee.tsv",
  "mtfDir": "/var/m1mtf",
  "programmingCommand": "/opt/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI"
}
```

Use values appropriate to the installed fixture, product, and production site. The fields are:

- `productName`: target product variant, for example `m1-3200` or `mnplus`.
- `tfInterface`: fixture Ethernet interface.
- `vendorSite`: manufacturing site identifier.
- `fwDir` and `layoutFilePath`: firmware and flash-layout paths below `mtfDir`.
- `mtfDir`: shared fixture firmware and log directory; use `/var/m1mtf`.
- `programmingCommand`: absolute path to the STM32CubeProgrammer CLI executable.
- `coinCellMinVoltageNew`: minimum coin-cell voltage for `--cellBatTol new`.
- `coinCellMinVoltageUsed`: minimum coin-cell voltage for `--cellBatTol used`.
- `skipTestpointCheck`, `skipRS485test`, `skipBatteryTest`, and `forceEppromOverwrite`: production-test behavior controls.

## Operator UI PIN Gate

`productionPassword` and `debugPassword` in `config.json` gate the "production"
and "debug" views in the operator UI (`m1-rest-server`'s `/auth` and
`/changepin` routes). This is a UI convenience to keep regular operators out
of the debug log view, not a network access control — the REST API itself
does not require a PIN to execute fixture commands, so it must only run on a
controlled, isolated fixture LAN.

`config.json` is the only place these PINs live; `m1-rest-server` has no
built-in default and requires them to be present. `provision-new-pc/setup/setup.sh`
inserts default values (`productionPassword: "1234"`, `debugPassword: "4321"`)
when it creates `config.json` on a freshly provisioned fixture PC. Change them
per-site with:

```bash
sudoedit /etc/m1platform/config.json
```

Some deployments also store service credentials or production passwords in this file. Do not copy those values into source control, logs, or documentation. Apply host access controls appropriate to the users and services that must run `m1tfc`.

Edit and validate the file:

```bash
sudoedit /etc/m1platform/config.json
sudo jq -e . /etc/m1platform/config.json >/dev/null
sudo jq -e '{mtfDir, programmingCommand}' /etc/m1platform/config.json
sudo test -r /var/m1mtf/fsbl.stm32
sudo test -x /opt/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI
```

## calibration.json

`calibration.json` stores test-board-specific analog calibration and expected values. Its top-level structure is:

```json
{
  "boards": [
    {
      "testPointsMnp": [],
      "testPointsM1": [],
      "ribbonCableA2DPins": [],
      "strikeReg": [],
      "ddrVoltageM1": {},
      "ddrVoltageMnp": {},
      "coinCellBattery": {
        "name": "BatCellBat",
        "minVoltageNew": 3.0,
        "minVoltageAged": 2.9,
        "scale": 1
      }
    }
  ]
}
```

The `boards` array is indexed by the test-board firmware board ID. A board ID of `n` uses `boards[n]`; preserve array positions when adding or updating a calibration profile. The individual test-point entries contain the measured point name, expected voltage, and scale where applicable.

The calibration process owns the measured values. On load, `m1tfc` expands missing, empty, or incomplete board profiles to the built-in defaults, then calibration saves the measured scales back to this file. Existing non-empty calibration groups are preserved.

### New Fixture Bootstrap

For a new fixture, create `/etc/m1platform/calibration.json` with this starter structure:

```json
{
  "boards": [
    {
      "testPointsMnp": [],
      "testPointsM1": [],
      "ribbonCableA2DPins": [],
      "strikeReg": [],
      "ddrVoltageM1": {},
      "ddrVoltageMnp": {},
      "coinCellBattery": {
        "name": "BatCellBat",
        "minVoltageNew": 3.0,
        "minVoltageAged": 2.9,
        "scale": 1
      }
    }
  ]
}
```

This is a seed, not a complete calibration. `m1tfc` expands it to 20 default board profiles before running ICT. Run the ICT calibration process as root to measure the fixture and save its calibrated values:

```bash
sudo m1tfc ict \
  --serial <vendor-serial> \
  --debug 1 \
  --cellBatTol used \
  --calibrate true
```

During calibration the process updates the measured scales and writes the resulting JSON to `/etc/m1platform/calibration.json`. A failed calibration can leave the file only partially updated; correct the fixture issue and rerun calibration before using the fixture for production.

Confirm the bootstrap created the expected structure:

```bash
sudo jq -e '.boards | type == "array" and length == 20' \
  /etc/m1platform/calibration.json
```

Back up the file before changing a known-good production calibration:

```bash
sudo cp /etc/m1platform/calibration.json \
  /etc/m1platform/calibration.json.bak-$(date +%Y%m%d%H%M%S)
sudoedit /etc/m1platform/calibration.json
sudo jq -e '.boards | type == "array"' /etc/m1platform/calibration.json
```

## Operational Check

After changing paths or configuration, run a normal ICT operation. The log must show the shared absolute firmware path:

```text
Executing ICT command /var/m1mtf/fsbl.stm32 ...
```

A DFU timeout after this message is a fixture/boot-mode/programmer issue. If the log instead shows `/root/m1mtf/...`, `mtfDir` was not loaded from `/etc/m1platform/config.json`.

## MAC Address Allocation

The M1-3200 and MNPlus test fixtures share OUI EUI-48 block `58-FC-C8`.
Each fixture station is assigned a dedicated 1,000,000-address block,
starting at the base MAC below (the station's `STARTMAC`, see
`setup/setup.sh` usage), to avoid UID collisions between stations.

### M1-3200 Fixtures

| Station    | Base MAC              |
|------------|------------------------|
| m1-3200-1  | 58:FC:C8:00:00:00      |
| m1-3200-2  | 58:FC:C8:0F:42:40      |
| m1-3200-3  | 58:FC:C8:1E:84:80      |
| m1-3200-4  | 58:FC:C8:2D:C6:C0      |
| m1-3200-5  | 58:FC:C8:3D:09:00      |
| m1-3200-6  | 58:FC:C8:4C:4B:40      |
| m1-3200-7  | 58:FC:C8:5B:8D:80      |
| m1-3200-8  | 58:FC:C8:6A:CF:C0      |

### MNPlus Fixtures

| Station    | Base MAC              |
|------------|------------------------|
| mnplus-1   | 58:FC:C8:7A:12:00      |
| mnplus-2   | 58:FC:C8:89:54:40      |
| mnplus-3   | 58:FC:C8:98:96:80      |
| mnplus-4   | 58:FC:C8:A7:D8:C0      |
| mnplus-5   | 58:FC:C8:B7:1B:00      |
| mnplus-6   | 58:FC:C8:C6:5D:40      |
| mnplus-7   | 58:FC:C8:D5:9F:80      |
| mnplus-8   | 58:FC:C8:E4:E1:C0      |

> Verified `mnptestf5` UID base is `58:FC:C8:A7:D8:C0`, which falls in
> the `mnplus-4` slot above — hostname numbers may not map 1:1 to slot
> numbers. Confirm actual per-station assignments before relying on
> this table for provisioning new fixtures.

