# SW / FW Data Flow and Top-Level Architecture

This diagram shows the top-level data flow across the fixture's software and firmware components, with the UUT (unit under test) at the top. The fixture interface boards sit between the PC and the UUT since that is the actual signal path (PC commands the boards, boards drive the UUT); this keeps every arrow a short, uncrossed hop instead of long lines looping back over each other. `m1-cloud-client` is out of scope — it is not part of the fixture test data path.

```mermaid
flowchart BT
    classDef pc fill:#eef3ff,stroke:#3367d6,color:#1a237e;
    classDef fixfw fill:#fff6e8,stroke:#e65100,color:#5d3a00;
    classDef uut fill:#eaf7ec,stroke:#2e7d32,color:#1b3d1f;

    subgraph PC["PC Ubuntu 26.04 server"]
        direction LR
        UI["m1-operator-ui"]:::pc
        REST["m1-rest-server"]:::pc
        TFC["m1tfc"]:::pc
        UI -->|REST| REST -->|dispatch| TFC
    end

    M1FW["m1testBoardFw"]:::fixfw
    ACMFW["acm-testboard-fw"]:::fixfw

    subgraph UUT["UUT - stm32mp1-baremetal FW or Linux"]
        direction LR
        UUT_SER["stm32mp1-baremetal<br/>UUT serial header"]:::uut
        UUT_BOOT["Boot mode pins<br/>Test points"]:::uut
        UUT_USB["USB/DFU"]:::uut
        UUT_ACM["Access control HW"]:::uut
    end

    TFC -->|Serial| M1FW
    TFC -->|Serial| UUT_SER
    TFC -->|UDP| ACMFW
    TFC -->|USB| UUT_USB

    M1FW -->|GPIO boot-select (1 pin) + GPIO/A-D test points| UUT_BOOT
    ACMFW -->|Access I/O| UUT_ACM
```

## Components

| Component | Repo path | Role |
| --- | --- | --- |
| `m1-operator-ui` | `components/m1-operator-ui` | Operator-facing React application running on the fixture host PC. |
| `m1-rest-server` | `components/m1-rest-server` | Runs on the PC. Acts as a bridge between the React UI and `m1tfc`; it contains no test logic. |
| `m1tfc` | `components/m1tfc` | Runs on the PC. Stands for M1 Test Fixture Control, owns the test workflow, and controls all hardware interfaces below. |
| `m1testBoardFw` | `components/m1testBoardFw` | Firmware for the M1 Test Board. Connected to the PC over a dedicated serial link. Uses one GPIO boot-select control pin for UUT boot mode, and uses GPIO/A-D channels for fixture testing at UUT test points. |
| `acm-testboard-fw` | `components/acm-testboard-fw` | Firmware for the ACM Test Board. Connected to the PC over UDP. Exercises the UUT's access-control hardware. |
| `stm32mp1-baremetal` | `components/stm32mp1-baremetal` | Firmware downloaded to the UUT with DFU helper flow and then run on bare metal. It is accessible via the UUT serial header, and `m1tfc` communicates with it over a dedicated serial link independent of the M1 Test Board link. |
| UUT | — | Also has a direct USB link to the PC for DFU and SSD programming after the boot-select pins are set to the required boot target. |

## Data Flow Narrative

1. The operator uses `m1-operator-ui` in a browser, and the UI calls `m1-rest-server` through an HTTP REST API.
2. `m1-rest-server` forwards commands to `m1tfc`, which owns all test sequencing and logic. Neither the UI nor the REST layer communicates with hardware directly.
3. `m1tfc` is the sole owner of the hardware links. It opens three independent command channels: serial to the M1 Test Board (`m1testBoardFw`), a separate direct serial link to the UUT firmware (`stm32mp1-baremetal`), and UDP to the Mercury Test Board (`mercury-testboard-fw`).
4. `m1tfc` also uses a direct USB link to the UUT for DFU-mode firmware and SSD programming.
5. `m1testBoardFw` sets UUT boot mode with one GPIO boot-select control pin (normal boot, DFU for SSD programming, or download-and-execute of `stm32mp1-baremetal`). GPIO/A-D channels are used for fixture test-point measurements, not for firmware download.
6. `mercury-testboard-fw` exercises the UUT access-control hardware.
7. All three firmware targets use the same command/response model: `m1tfc` sends a command, and the firmware returns JSON (`status`, `error`, plus optional data). `mercury-testboard-fw` carries the same JSON framing over UDP instead of serial.

## Out of Scope

- `m1-cloud-client` — not part of the fixture test data path (cloud/update/secrets client, separate concern).
- `tfcroncli` — cron-scheduled cloud-update function, not fixture test operation related.
