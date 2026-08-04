# Cloud Deployment Documentation

This directory holds documentation for the EVM platform's cloud-hosted
resources — currently Azure Blob Storage, and any other cloud files/services
the platform uses going forward.

## Azure Subscription

All Azure Storage used by the platform is under:

- **Subscription**: Lenel Cloud Security Product Development (`135693b9-b629-4251-a45e-bbdd4727ab52`)
- **Resource group**: `lenel-common-eng-rg`
- **Location**: East US
- **Storage account**: `lenels2boardsprodsa`

## `m1mnplus-testing-platform` container

This container organizes per-test-fixture data. Each test fixture has its
own top-level directory (named after the fixture), and each fixture
directory contains three fixed subdirectories:

- **`logs/`** — that fixture's run/test logs, kept separate per fixture so
  logs from one fixture never mix with another's and can be retrieved or
  purged independently.
- **`secrets/`** — that fixture's credentials/keys (e.g. connection
  strings, certificates), scoped per fixture so a compromise or rotation
  on one fixture doesn't expose or require touching another fixture's
  secrets.
- **`fixtureFWSW/`** — that fixture's own PC software, custom test-board
  firmware, and target baremetal firmware, kept per fixture so each
  fixture can run its own versions independently of the others. See
  `Readme-Fixture-SW-FW` inside this directory for details.
- **`productFW/`** — the production firmware for the M1-3200 and MNPlus
  products under test, scoped per fixture so each fixture flashes/tracks
  the exact release it's been validated against. See `Readme-productFW`
  inside this directory for details.
- **`database-backup/`** — that fixture's database backups, isolated per
  fixture so each fixture's backup/restore history stays independent and
  a restore on one fixture can't accidentally pull another fixture's data.
