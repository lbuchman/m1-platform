# Firmware Publishing (Azure Blob `firmware` container)

Requirements:

- `manifestFile.json` is auto-created in `artifacts/` by `scripts/build.sh` as each artifact is built; `scripts/publish-fw.sh` blocks upload if it's missing entries or any file's SHA-512 doesn't match.
- Upload via the `az` CLI using an Azure Storage connection string. `scripts/publish-fw.sh` reads the connection string from `--destination-url`, or falls back to the `conString` in `azureStorage.json` at the repo root if `--destination-url` is omitted. `azureStorage.json` is not committed to the repo (see `.gitignore`).

Firmware publishing is handled through `scripts/publish-fw.sh`.

Before running `scripts/publish-fw.sh`, build artifacts first:

```bash
./scripts/build.sh build all
```

Then publish using existing artifacts only:

```bash
./scripts/publish-fw.sh
```
