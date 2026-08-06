# Uploading SW/FW to Cloud

Updating the firmware/software files in `fixtureFWSW/` and `productFW/`
is automatic: `scripts/publish-fw.sh` uploads the files plus a generated
`manifestFile.json` to the `m1mnplus-testing-platform` container, and
each fixture's `tfcroncli`/`m1client` polls that container and downloads
updates on its own.

See [`scripts/publish-fw.sh`](../../scripts/publish-fw.sh)
for the upload command and usage.
