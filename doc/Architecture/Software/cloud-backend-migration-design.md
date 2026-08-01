# Factory Server Migration: Azure Blob Storage → Local On-Prem Server

## Goal

Replace the current Azure Blob Storage based system (`tfcroncli`/`m1client` on the fixture, `m1-cloud-client`/`m1CloudClient` for admins) with a **local, on-prem physical PC in the factory** ("Factory Server") that the team fully controls. This is a hard requirement, not just a preference: production lines must be **self-contained** and must keep running even if internet/cloud connectivity is down — nothing on the primary production path (logs, secrets, firmware updates, MAC allocation) may depend on reaching the internet. The new backend must:

1. Store logs, retrievable **by board serial number** (today only retrievable by date-prefix/fixture).
2. Store secrets, retrievable **by board serial number** (same limitation today).
3. Host firmware/software releases; fixtures poll and self-update (replaces the `firmware` blob container + `manifestFile.json`).
4. Centrally manage MAC address allocation (replaces the static, offline `STARTMAC` block-per-fixture formula in `setup.sh`).
5. Provide a web app to browse all of the above.
6. Run entirely on the factory LAN — Azure Blob Storage is retained only as an **off-site daily backup target** (disaster recovery), never on the critical path for production.
7. Keep test fixture PCs **stateless/thin clients** — since the Factory Server now owns the only database, fixtures no longer need a local database at all. Board test results, secrets, and MAC assignment are written directly and immediately to `m1-factory-hub` over the LAN instead of being staged in a local SQLite DB and synced later by cron.

## Naming

Recommended service name: **`m1-factory-hub`**. "Factory Server" refers to the physical on-prem PC (the hardware); `m1-factory-hub` is the Node/Express service that runs on it, following the existing `m1-<role>` naming convention (`m1-rest-server`, `m1-operator-ui`, `m1-cloud-client`). "Hub" reflects its role as the single central point every fixture talks to for logs, secrets, firmware, and MAC allocation. Alternatives considered: `m1-mes-server` (accurate — this is effectively a small Manufacturing Execution System — but a less familiar term), `m1-depot` (evokes storage but undersells the MAC-allocation/coordination role). The rest of this doc uses `m1-factory-hub`.

## Current State (for reference)

| Concern | Current mechanism |
| --- | --- |
| Logs | Fixture cron (`m1client synclogs`) uploads `.txz` archives to `<product>-logs-<site>` Azure container. Retrieval only by date-prefix, no serial index. |
| Secrets | Fixture cron (`m1client syncsecrets`) uploads a CSV of RSA-encrypted, base32-encoded secrets to `<product>-secrets` container. |
| Firmware | Admin tool `m1CloudClient uploadfw` pushes files + `manifestFile.json` to `firmware` container; fixture cron (`m1client update`) polls and downloads. |
| DB backup | Fixture cron (`m1client backupdb`) uploads SQLite `tf.db` to `backup` container. |
| MAC addresses | `setup.sh` computes a static `58:FC:C8:%02X:%02X:%02X` block per fixture from `idx * 1_000_000`, seeded once into the local `UID` table at provisioning. No central registry, no collision detection. |

## `deployment` Container Contract (Azure Blob, current interim mechanism)

Manual firmware releases are staged in the `deployment` Azure Blob container ahead of the on-prem migration above. This container **MUST** contain, at minimum:

- `stm32mp15-lenels2-m1.txz` — M1 firmware image archive.
- `stm32mp15-lenels2-mnp.txz` — MNP firmware image archive.
- `manifestFile.json` — SAS URLs and SHA-512 hashes for both archives above (`m1firmware` / `mnpfirmware` entries).

Each `.txz` archive **MUST** contain, at its root, a `VERSION` file — plain text, exactly **1 line**, containing the Artifactory-reported build revision string. Example:

  ```
  1.0.16 179 09/22/23 02eef93c27 M1B SandboxHost-638309047983092644
  ```

  Format: `<version> <build number> <build date MM/DD/YY> <short commit sha> <product> <build host>`.

## Proposed Architecture

```mermaid
flowchart LR
    classDef fixture fill:#eef3ff,stroke:#3367d6,color:#1a237e;
    classDef vm fill:#fff6e8,stroke:#e65100,color:#5d3a00;
    classDef admin fill:#eaf7ec,stroke:#2e7d32,color:#1b3d1f;
    classDef cloud fill:#f3e8ff,stroke:#6a1b9a,color:#3a1a5d;

    subgraph LAN["Factory LAN (no internet dependency for production)"]
        subgraph FIX["Test Fixture PCs (stateless — no local DB)"]
            MTFC["m1tfc<br/>(test execution — calls Hub in real time\nfor boards / secrets / mac allocate)"]:::fixture
            TFC["tfcroncli / m1client<br/>(cron: update only)"]:::fixture
            SSH1["autossh"]:::fixture
        end

        subgraph SRV["Factory Server (on-prem PC) — m1-factory-hub"]
            API["m1-factory-hub (Express REST API)"]:::vm
            MYSQL[("MySQL: boards, logs, secrets,\nmac_allocations, firmware_releases")]:::vm
            FS[("Filesystem: /data/logs, /data/firmware,\n/data/secrets, /data/backups")]:::vm
            WEB["Web dashboard (React)"]:::vm
            BKUP["daily backup job<br/>(mysqldump + tar, conditional)"]:::vm
            SSH2["autossh"]:::vm
            API --- MYSQL
            API --- FS
            WEB -->|REST| API
            BKUP --- MYSQL
            BKUP --- FS
        end

        subgraph ADMIN["Engineer workstation"]
            CLI["m1-cloud-client (m1CloudClient)<br/>uploadfw / getsecrets / getlogs"]:::admin
        end

        MTFC -->|HTTPS + API key, LAN only\nreal-time board/secret/mac calls| API
        TFC -->|HTTPS + API key, LAN only\nfirmware update poll| API
        CLI -->|HTTPS + API key, LAN only| API
    end

    AZURE[("Azure Blob Storage<br/>off-site DR backup only")]:::cloud
    RELAY[("External relay server")]:::cloud

    BKUP -.->|daily, only if changed,\nvia existing access key| AZURE
    SSH1 -.->|reverse SSH tunnel\n(remote support access)| RELAY
    SSH2 -.->|reverse SSH tunnel\n(remote support access)| RELAY
```

The reverse-SSH-via-relay pattern already exists on every test fixture PC (`autossh` service, restarted on boot via cron — see `setup.sh`) purely for remote engineering/support access; it carries no production data and is independent of the `m1-factory-hub` REST path and the Azure backup path. The Factory Server should get the same `autossh` service for the same reason (remote troubleshooting), not because production depends on it.

Because fixtures now depend on `m1-factory-hub` being reachable *during* live test execution (not just for periodic batch sync), the Factory Server effectively becomes a production-critical LAN service. This is a reasonable trade for the simplicity gained (see Open Decisions for reliability/retry considerations).

## Factory Server Components

### Database: MySQL

MySQL (InnoDB) replaces Postgres per your preference. Suggested schema:

```sql
CREATE TABLE boards (
  serial          VARCHAR(64) PRIMARY KEY,
  product         VARCHAR(32) NOT NULL,
  mac             VARCHAR(17) UNIQUE,
  fixture         VARCHAR(32),
  status          VARCHAR(32) DEFAULT 'active',
  created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE logs (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  board_serial    VARCHAR(64) NOT NULL,
  fixture         VARCHAR(32) NOT NULL,
  file_path       VARCHAR(512) NOT NULL,
  file_hash       CHAR(128) NOT NULL,
  size_bytes      BIGINT,
  uploaded_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (board_serial) REFERENCES boards(serial),
  INDEX idx_logs_serial (board_serial)
) ENGINE=InnoDB;

CREATE TABLE secrets (
  board_serial      VARCHAR(64) PRIMARY KEY,
  uid               VARCHAR(64) NOT NULL,
  encrypted_secret  TEXT NOT NULL,
  fixture           VARCHAR(32),
  synced_at         DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (board_serial) REFERENCES boards(serial)
) ENGINE=InnoDB;

CREATE TABLE mac_allocations (
  mac             VARCHAR(17) PRIMARY KEY,
  board_serial    VARCHAR(64) UNIQUE,
  fixture         VARCHAR(32),
  status          ENUM('available','reserved','assigned') DEFAULT 'available',
  allocated_at    DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE firmware_releases (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  version         VARCHAR(32) NOT NULL,
  product         VARCHAR(32) NOT NULL,
  filetype        VARCHAR(16) NOT NULL,
  filename        VARCHAR(255) NOT NULL,
  file_hash       CHAR(128) NOT NULL,
  published_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_release (version, product, filetype)
) ENGINE=InnoDB;
```

Note: no `db_backups` table is needed anymore — there is no per-fixture local database left to back up. The `boards` table itself (with test-result columns such as `ict_passed`, `functional_passed`, `flash_programmed`, mirroring today's local `records` table) *is* the durable store now, and it lives only on the Factory Server, covered by the single off-site backup job described below.

`mysql2` (Node driver, promise support built in) on the Factory Server only — fixtures never talk to MySQL directly, only through the `m1-factory-hub` REST API.

### File storage

Plain filesystem on the Factory Server (`/data/logs/<serial>/...`, `/data/firmware/<product>/<version>/...`, `/data/backups/<fixture>/...`), indexed by the MySQL rows above. No need for MinIO/S3-compatible layers at this scale — it adds an extra moving part for no real benefit here.

### REST API (`m1-factory-hub`, Express — new component, e.g. `components/m1-factory-hub`)

| Method | Endpoint | Purpose |
| --- | --- | --- |
| POST | `/api/logs` | Fixture uploads a log archive tagged with `serial`, `fixture`, timestamp. |
| GET | `/api/logs?serial=` | List/download logs for a board. |
| POST | `/api/secrets` | Fixture uploads an (already RSA-encrypted) secret record for a board. |
| GET | `/api/secrets?serial=` | Retrieve a board's secret record. |
| POST | `/api/mac/allocate` | Fixture/`setup.sh` requests the next free MAC; server allocates atomically and marks it `assigned`. |
| GET | `/api/mac?serial=` | Look up a board's assigned MAC. |
| GET | `/api/firmware/manifest?product=` | Replaces Azure `manifestFile.json` fetch — fixture's `update` command polls this. |
| GET | `/api/firmware/:file` | Download a firmware/snap file. |
| POST | `/api/firmware` | Admin publishes a new release (replaces `m1CloudClient uploadfw`). |
| POST | `/api/boards` | `m1tfc` records/updates a board's test result in real time (ICT/functional pass, flash programmed, etc.) — replaces the local `records` table. |
| GET | `/api/boards?serial=` | Look up a board's current test/status record (e.g., to resume or re-test). |
| GET | `/health` | Health check (same base-response contract pattern already used in `m1-rest-server`). |

### Auth

The Factory Server sits on the same factory LAN as the fixtures, so there's no public domain/Let's Encrypt concern here. Recommended default: HTTPS with a self-signed cert (or a small internal CA) issued once and distributed to fixtures via `setup.sh` (`update-ca-certificates`), plus a per-fixture API key issued at provisioning time, sent as `Authorization: Bearer <key>`. TLS is still worthwhile even on a trusted LAN (defense in depth for the secrets endpoint); plain HTTP is not recommended. A static hostname/IP for the Factory Server (e.g. `factory-server.local` via mDNS, or a fixed LAN IP) should be baked into fixture config at provisioning time.

### Web app

Reuse the existing pattern (`m1-operator-ui`: React/Vite, talking to an Express REST layer) rather than a new stack: search by board serial → logs, secret-sync status, MAC, firmware history; plus an admin view for firmware releases and the MAC pool. Runs on the Factory Server itself, accessible from any PC on the factory LAN.

## Off-Site Backup to Azure Blob Storage

Azure Storage is **not** part of the operational path anymore — it is only a daily, best-effort, off-site disaster-recovery copy, using the access key already held. Production continues normally even if this fails or if internet access is temporarily down.

- **What**: a `mysqldump` of the MySQL database + a tarball of `/data` (logs/secrets/firmware/backups), run once daily on the Factory Server itself (not on individual fixtures).
- **Conditional upload**: track a watermark (e.g. `MAX(updated_at)` across the relevant tables, or a hash of the dump) from the last successful backup; skip the upload entirely if nothing changed since then, to avoid needless daily transfers.
- **Isolation from the app code**: implement this as a standalone ops script (bash + `mysqldump` + `azcopy` or `az storage blob upload-batch`), run via a systemd timer/cron on the Factory Server — kept entirely separate from the Node REST API. This keeps the application code itself fully vendor-neutral; only this one backup script touches Azure, using the existing storage account access key (e.g. a dedicated `factory-backup` container).
- **Restore path**: download the latest dump/tarball from Azure and restore `mysqldump` + extract `/data` onto a replacement Factory Server.

## Remote Support Access (autossh reverse SSH)

Separate from both the production data path and the Azure backup path: every test fixture PC already runs an `autossh` service that opens a reverse SSH tunnel to an external relay server, giving engineers remote shell access for troubleshooting (already implemented, restarted on boot via the existing `@reboot sleep 120 && systemctl restart autossh` cron entry in `setup.sh`). The Factory Server should run the same `autossh` service against the same relay, for the same reason — remote support access if on-site visits aren't practical. This channel carries no logs/secrets/firmware/MAC traffic and has no bearing on the self-contained-production requirement; it's purely an admin convenience.

## Test Fixture PC Software Changes

The fixture host already runs Ubuntu Server + Node.js (via the `m1client`/`tfcroncli` snap) and needs no new system-level packages for this migration — just dependency and config changes:

| Area | Change |
| --- | --- |
| `tfcroncli/app/package.json` & `m1-cloud-client/package.json` | Remove `azure-storage`, `@azure/storage-blob`. No new HTTP dependency needed — Node 20+ (already the baseline per `m1-rest-server`'s `engines`) has built-in `fetch`, `FormData`, and `Blob`, sufficient for multipart uploads/downloads. |
| `azureOp.js` | Replaced by a new `httpOp.js` with the same exported function shapes (`syncFiles`, `checkFilesHash`, `getHash512FromFile` — the hash helper is pure local logic and doesn't change) so `m1client.js`'s command bodies barely change, just the transport underneath. |
| `/etc/m1platform/config.json` | `conString` field replaced by `apiBaseUrl` + `apiKey`. `setup.sh`'s config-writing heredoc needs updating accordingly. |
| `better-sqlite3` (and the local `tf.db`/`records`/`UID`/`Perm` schema) | **Removed entirely.** No local database on the fixture at all — `m1tfc` calls `m1-factory-hub` directly for board test-result records, secret submission, and MAC allocation instead of writing to local SQLite and syncing later. This also drops a native module (`better-sqlite3` requires compilation) from every fixture install. |
| `m1tfc` (test executor, `components/m1tfc`) | Bigger change than `tfcroncli`: the code that used to read/write the local `records`/`UID` tables now calls `m1-factory-hub`'s `/api/boards`, `/api/secrets`, and `/api/mac/allocate` synchronously during the test sequence. Needs basic retry/backoff around these calls since the Hub is now a live dependency during test execution, not just a periodic sync target. |
| `crypto` (RSA), `winston`, `fs-extra`, `glob`, `mkdirp`, `date-and-time`, `lodash` | Unchanged — encryption and logging stay exactly as they are today. |
| TLS trust | The Factory Server will use a self-signed cert or small internal CA (no public domain on a factory LAN). `setup.sh` needs a step to install that CA into each fixture's system trust store (`update-ca-certificates`). |
| MySQL client | **Not needed** on the fixture — all DB access is server-side only, fixtures only ever call the REST API. |
| cron schedule | `tfcroncli`/`m1client` shrinks to just `update` (firmware polling). `synclogs`, `syncsecrets`, `backupdb` and their log-retention `find`/`delete` jobs are all removed — there's no local state left to batch-sync since logs/secrets/board records now push in real time from `m1tfc` itself. |
| `setup.sh` MAC provisioning | Removed entirely — no `STARTMAC`/`idx * 1_000_000` block calculation, no local `UID` table to seed. MACs are requested per-board, at programming time, directly from `m1-factory-hub`. |
| Package footprint | Net reduction — dropping the Azure SDKs *and* `better-sqlite3` removes two fairly heavy/native dependency trees from every fixture install. |

## Migration Plan (staged)

1. Procure/set up the Factory Server (physical PC on the factory LAN) with MySQL + `m1-factory-hub` + filesystem storage, and the same `autossh` remote-support service already used on fixtures; implement and test all endpoints above in isolation.
2. Add `httpOp.js` to `tfcroncli`/`m1-cloud-client` for firmware `update` (behind the same interface as `azureOp.js`), and add the direct `m1tfc` → `m1-factory-hub` calls for boards/secrets/mac-allocate (replacing the local `records`/`UID` table reads/writes in `m1tfc`). Update `config.json`/`setup.sh` to point at the Factory Server's LAN address. Pilot on one fixture before wider rollout.
3. Cut fixtures over fixture-by-fixture (`update` retargeted; local SQLite removed; `m1tfc` now calls the Hub directly).
4. Move MAC allocation to the central API last — highest process risk. Consider registering existing static allocations into `mac_allocations` first (for visibility) before fixtures start requesting *new* MACs from the pool.
5. Stand up the daily conditional Azure backup job on the Factory Server (independent ops script, see below).
6. Historical Azure data and existing local `tf.db` records: import into the Factory Server's MySQL as a one-time migration, or leave archived — no need to block the cutover on this.

## Open Decisions

- **Auth model**: API key over HTTPS with a self-signed/internal CA (recommended default above), or mutual TLS client certs?
- **Factory Server addressing**: fixed LAN IP vs. mDNS/local hostname — which is already standard practice on this network?
- **MAC cutover**: keep the static per-fixture formula as an offline fallback (e.g. if the Factory Server is briefly down for maintenance), or make Factory Server reachability a hard requirement for `setup.sh`/provisioning to complete?
- **Historical data**: import existing Azure blob data (and existing local `tf.db` records) into the new system, or leave archived as-is?
- **Backup retention**: how many days/versions of the daily Azure backup to retain before pruning older ones?
- **Test-time reliability**: since fixtures now depend on `m1-factory-hub` being up *during* live testing (no local DB fallback), what retry/backoff policy should `m1tfc` use on a transient failure, and should the Factory Server run on a UPS/have any redundancy given it's now production-critical?
