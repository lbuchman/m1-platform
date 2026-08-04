# Uploading SW/FW to Cloud

Updating the firmware/software files in `fixtureFWSW/` and `productFW/`
is automatic: `m1-cloud-client` uploads the files plus a generated
`manifestFile.json` to the `m1mnplus-testing-platform` container, and
each fixture's `tfcroncli`/`m1client` polls that container and downloads
updates on its own.

See [`components/m1-cloud-client/README.md`](../../components/m1-cloud-client/README.md)
for the upload command and usage.
