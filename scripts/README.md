# Scripts

Automation used to bootstrap, build, program, and publish the M1 platform.

| Script | Purpose |
| --- | --- |
| `build.sh` | Builds firmware (`acm`, `fixture`, `stm32mp1`) and platform Snaps (`m1tfc`, `m1-rest-server`, `m1-operator-ui`); stages artifacts and `manifestFile.json` in `artifacts/`. |
| `check-dirty-components.sh` | Reports Git cleanliness (clean/dirty/not-git) for each repo under `components/`. |
| `clone-components.sh` | Clones all split `components/*` repos via SSH (falls back to HTTPS); `--update` fast-forwards existing clones. |
| `install-snaps.sh` | Copies built snaps from `artifacts/` to a remote host via `scp` and installs them there via `ssh`. |
| `installstm32fsbl.sh` | Copies the built STM32MP1 ICT FSBL (`artifacts/stm32mp1_fsbl.stm32`) to `/var/m1mtf/fsbl.stm32` on a remote host. |
| `prog-teensy.sh` | Uploads prebuilt Teensy firmware (`acmfirmware.hex` or `m1firmware.hex`) to a board over a remote host's `teensy_loader_cli`. |
| `publish-fw.sh` | Uploads firmware, snap, and manifest artifacts from `artifacts/` to Azure Blob storage. |
| `update-components.sh` | Fast-forward pulls already-cloned `components/*` repos without re-cloning; supports `--component` and `--dry-run`. |

Run any script with `-h`/`--help` (where supported) for full usage and options.
