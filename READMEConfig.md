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
  "programmingCommand": "/home/lenel/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI"
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

Some deployments also store service credentials or production passwords in this file. Do not copy those values into source control, logs, or documentation. Apply host access controls appropriate to the users and services that must run `m1tfc`.

Edit and validate the file:

```bash
sudoedit /etc/m1platform/config.json
sudo jq -e . /etc/m1platform/config.json >/dev/null
sudo jq -e '{mtfDir, programmingCommand}' /etc/m1platform/config.json
sudo test -r /var/m1mtf/fsbl.stm32
sudo test -x /home/lenel/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI
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
