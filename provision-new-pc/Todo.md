# Provisioning Security Todo

Open items found during review on 2026-08-05, to address before migrating this repo off `lbuchman`'s personal GitHub.

## Secrets committed to git (must be rotated, not just removed)

- `provision-new-pc/setup/id_rsa` — deploy SSH private key, shared across every fixture PC. Tracked in git since commit `f3b2f7a`. Treat as compromised regardless of any future repo cleanup.
- `provision-new-pc/setup/cloud.key` — `autossh.service` reverse-tunnel private key (target -> `relay.sputnik-em.com`), also shared across every fixture PC. Tracked in git alongside `id_rsa`. Replacement plan not yet decided.
- `provision-new-pc/setup/setup.sh` — hardcodes live Azure SAS tokens (firmware blob URLs + `firmwareManifestUrl`) with `se=2036-08-01` expiry, written verbatim into every target's `/etc/m1platform/config.json`.

## Design questions, not yet decided

- Replace the one-shared-keypair-for-all-fixtures model with a unique keypair generated per fixture PC (reduces blast radius, allows per-PC revocation).
- Decide what happens to `cloud.key` / the reverse-tunnel model — unresolved.
- Move the SAS tokens in `setup.sh` out of the script into an out-of-band input (same pattern as `azureStorage.json`) instead of hardcoding them.

## Before any repo migration

- Rotate `id_rsa`, `cloud.key`, and the embedded SAS tokens — old values must be treated as burned, independent of any git history cleanup.
- Purge `id_rsa`, `cloud.key`, and the historical SAS-token commits from git history (e.g. `git filter-repo`/BFG) — deleting the files in a new commit alone does not remove them from history.
