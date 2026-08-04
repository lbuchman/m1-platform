# EVM Platform Documentation v1.2

This package is the controlled documentation baseline for the M1/MNPlus Unified Engineering, Validation and Manufacturing Platform (EVM).

## Included formal documents

- EVM Platform Overview
- EVM Platform Capabilities
- EVM Hardware Architecture
- Engineering vs Production Configurations
- M1 Test Board Hardware Specification
- Mercury Controller Test Board Hardware Specification
- Production Fixture Assembly Guide
- EVM Twenty-Year Sustainment Plan
- M1 Operator UI Guide (`Operations/`)
- Fast Smoke Test Checklist (`Validation/`)
- Cloud deployment documentation, including board firmware storage / Azure `firmware` container contents (`Cloud-Deployment/`)

## Included engineering sources

- EVM architecture diagram image and draw.io source (`Architecture/Platform/Source-Diagrams/`)
- Current fixture design review diagram (`Architecture/Platform/Source-Diagrams/mnplus_design_review_v3.drawio`)
- Engineering bench photograph, production fixture photographs, and all document-extracted images (`Images/`)
- M1 Test Board and Mercury Controller Test Board schematic PDFs (`Architecture/Hardware/*/Source-Schematics/`)
- M1-3200 and MNPlus-V3 UUT (product-under-test) reference schematics (`Architecture/Hardware/UUT-Reference/`)
- Full architecture authoring context (`Architecture/Platform/Context/`)

## Repository layout

```text
doc/
├── Architecture/
│   ├── Platform/
│   │   ├── 01_EVM_Platform_Overview.md
│   │   ├── 02_EVM_Platform_Capabilities.md
│   │   ├── 03_EVM_Hardware_Architecture.md
│   │   ├── 04_Engineering_vs_Production_Configurations.md
│   │   ├── Context/            (full architecture authoring context)
│   │   └── Source-Diagrams/    (draw.io sources)
│   ├── Hardware/
│   │   ├── M1-Test-Board/                  (spec + Source-Schematics/)
│   │   ├── Mercury-Controller-Test-Board/   (aka ACM Board; spec + Source-Schematics/)
│   │   └── UUT-Reference/                  (M1-3200, MNPlus-V3 product schematics)
│   ├── Firmware/    (reserved)
│   └── Software/    (reserved)
├── Assembly/        (Production Fixture Assembly Guide)
├── Manufacturing/   (reserved)
├── Operations/      (operator UI guide)
├── Validation/      (fast smoke test checklist)
├── Sustainment/     (Twenty-Year Sustainment Plan)
├── Cloud-Deployment/ (cloud deployment docs: Azure storage containers, and other cloud files used by the platform)
├── Interface-Control-Documents/  (reserved: pogo-pin maps, IDC interface spec, reader interfaces)
└── Images/          (all diagrams/photos/document-extracted images)
```

## Scope note

The current package covers platform, hardware, assembly, operations, validation, and sustainment documentation. Detailed firmware, software, manufacturing release, and interface-control documents have reserved repository locations for future development.

The production fixture is one implementation of the broader EVM platform. The engineering bench and production fixture use the same core architecture with different mechanical and interface layers.

`Interface-Control-Documents/` was named out in full (rather than the `ICD` abbreviation) to avoid confusion with `IDC` (Insulation Displacement Connector), a distinct, frequently referenced term in the same interface documents.
