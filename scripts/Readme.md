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

## build.sh Usage

Build firmware and stage artifacts:

```bash
./scripts/build.sh build acm        # build ACM firmware
./scripts/build.sh build fixture     # build M1 fixture Teensy firmware
./scripts/build.sh build stm32mp1    # build STM32MP1 ICT FSBL
./scripts/build.sh build firmware    # build all firmware components
./scripts/build.sh build all         # build all firmware and all snaps
```

Build snap packages the same way:

```bash
./scripts/build.sh build m1tfc            # build m1tfc snap only
./scripts/build.sh build m1-rest-server   # build m1-rest-server snap only
./scripts/build.sh build m1-operator-ui   # build m1-operator-ui snap only
./scripts/build.sh build snaps            # build all snaps
```

Build artifacts are copied to `artifacts/` directly, alongside a
`build-manifest.txt` containing the source commit and dirty/clean state.
Use `--output-dir PATH` to select another artifact directory, `--update` for
fast-forward-only git updates from current remotes, or `--dry-run` to inspect
a command without building, installing, or programming hardware.

`build fixture` compiles `components/m1testBoardFw` with PlatformIO
(`pio run --environment teensy41`) and stages the resulting `.hex` as
`artifacts/m1firmware.hex`.
