# EVM Architecture and Documentation — Complete State

**Snapshot date:** July 25, 2026  
**Platform owner / principal designer:** Leo Buchman  
**Platform name:** M1/MNPlus Unified Engineering, Validation and Manufacturing Platform (EVM)  
**Document purpose:** Preserve the complete current understanding of the EVM architecture, hardware subsystems, deployment configurations, capabilities, source artifacts, repository organization, factory-documentation needs, and twenty-year sustainment requirements. This file is intended to provide enough context to generate the formal documentation package without repeating the discovery process.

---

## 1. Restore and Authoring Instructions

This file is the authoritative starting point for generating EVM documentation.

A future author or assistant should:

1. Treat the product as a platform, not merely a test fixture.
2. Start documentation at the platform level, then decompose into subsystems and implementations.
3. Distinguish the engineering bench configuration from the production fixture configuration.
4. Treat the M1 Test Board and ACM Controller Test Board as reusable platform subsystems.
5. Use the actual design-source files and schematics as authoritative implementation references.
6. Preserve the distinction between platform capability and the subset exposed by a product-specific plate, pogo-pin map, IDC connection, or wiring harness.
7. Keep software, firmware, operations, assembly, manufacturing, validation, sustainment, and interface-control documentation in separate but coordinated sections.
8. For the immediate documentation phase, prioritize hardware architecture and factory assembly. Detailed software, firmware, and operations documents remain future work unless explicitly requested.
9. Design every document with the twenty-year service-life requirement in mind.
10. Do not generate fake `.docx` files or placeholder text files with Word extensions. All office documents must be valid and rendered for quality assurance.

---

## 2. Executive Summary

The EVM is a reusable, multidisciplinary engineering platform supporting the complete product lifecycle across M1, MNPlus, ACM, and the broader ACM controller ecosystem.

The platform supports:

- Engineering development and bring-up.
- Hardware validation.
- Firmware validation.
- Software and system validation.
- Hardware-in-the-loop testing.
- QA and regression testing.
- Manufacturing provisioning and qualification.
- Production testing.
- Product recovery and regeneration.
- Failure analysis.
- Remote diagnostics and technical support.
- Cloud-connected updates, logs, secrets, and future enhancements.

The system was initially at risk of being described simply as a “test fixture.” That description is materially incomplete. The production fixture is one physical deployment of a broader platform. The platform also exists as an engineering bench configuration with direct terminal-block and IDC access, and the same hardware/software architecture can support development, QA, manufacturing, sustaining, and service activities.

The preferred formal name is:

> **M1/MNPlus Unified Engineering, Validation and Manufacturing Platform (EVM)**

The platform exhibits system engineering across mechanical, electrical, embedded firmware, software, networking, cloud, automation, product simulation, manufacturing, and sustainment domains.

---

## 3. Platform Naming and Terminology

### 3.1 Preferred platform name

**M1/MNPlus Unified Engineering, Validation and Manufacturing Platform (EVM)**

A shorter acceptable title is:

**M1/MNPlus Engineering, Validation and Manufacturing Platform**

### 3.2 Terms that undersell the architecture

Avoid using the following as the primary name:

- Test fixture.
- Production fixture.
- Automated tester.
- Board tester.

Those terms may describe an implementation or use case, but not the entire platform.

### 3.3 Preferred subsystem names

- **M1 Test Board**
- **ACM Controller Test Board**
- **SAM-E Ethernet Subsystem**
- **Platform Host / Headless PC**
- **Production Fixture Interface**
- **Engineering Direct-Access Interface**

### 3.4 Scope labels in the platform diagram

- **M1 Test Board (M1 Scope) — Teensy 4.1**
- **ACM Test Board (ACM Scope) — Teensy 4.1**

The labels explain why two Teensy-based boards exist. “ACM Scope” describes how the ACM board is used within the current MNPlus implementation; the board's full capability is much broader than ACM-only support.

---

## 4. Design Philosophy

The EVM was designed around workflows and lifecycle functions rather than around isolated technologies.

The design question was not:

- How can a Teensy be used?
- How can a React application be created?
- How can a board be tested?

The architectural question was:

> What common system can support engineering, QA, manufacturing, provisioning, recovery, regeneration, and support across multiple related products?

The design follows this hierarchy:

1. Business and lifecycle needs.
2. System requirements.
3. Functional decomposition.
4. Subsystem responsibilities.
5. Interface definitions.
6. Technology selection.
7. Product-specific physical adaptation.

The individual technologies are components or “bricks.” The EVM architecture is the “house.”

---

## 5. High-Level Capability Model

### 5.1 Engineering

- Product bring-up.
- Direct signal access.
- Firmware development.
- Software development.
- Debugging and diagnostics.
- Boot-target selection.
- Serial-console access.
- Ethernet communications.
- Device recovery.
- Hardware-in-the-loop simulation.
- Experimental and fault-injection workflows.

### 5.2 QA and validation

- Automated hardware validation.
- Automated firmware validation.
- Automated software validation.
- Serial-based testing.
- Ethernet-based testing.
- Functional and system testing.
- Regression testing.
- Product-family simulation.
- Reproducible validation environments.
- Test-result and log collection.

### 5.3 Manufacturing

- Firmware programming.
- Product provisioning.
- Configuration loading.
- Production qualification.
- Automated pass/fail testing.
- Device regeneration.
- Traceability support.
- Acceptance validation.

### 5.4 Sustaining and support

- Failure analysis.
- Serial and network diagnostics.
- Firmware recovery.
- Product regeneration.
- Log retrieval.
- Remote support.
- Controlled updates.
- Service workflows.

---

## 6. System Architecture Overview

### 6.1 Major physical subsystems

- Fanless headless PC.
- USB hub.
- M1 Test Board.
- ACM Controller Test Board.
- SAM-E three-port Ethernet switch.
- PoE power injector.
- 48 VDC power supply.
- 48 VDC relay control.
- 12.5 VDC / 5 VDC power supply.
- Lever switch and status LED/operator interface.
- Product-specific fixture plate.
- Pogo-pin bed for production configuration.
- Terminal blocks and direct harnesses for engineering configuration.
- UUT: M1 or MNPlus, depending on configuration.

### 6.2 Major software and service subsystems

- React-based operator interface.
- REST server running on the headless PC.
- Node.js application/test executor.
- Cloud client.
- CLI utilities.
- M1 Test Board firmware.
- ACM Controller Test Board firmware.
- STM32MP1 firmware and bare-metal support components.

### 6.3 Primary communications

- Ethernet.
- PoE.
- USB.
- Serial/UART.
- RS-485.
- OSDP.
- Wiegand.
- IDC/ribbon interface.
- Pogo-pin electrical interface.
- I2C and platform-specific control signals where applicable.

### 6.4 Primary power domains

- 120 VAC input.
- 12.5 VDC fixture/test electronics rail.
- 5 VDC SAM-E switch rail.
- 48 VDC PoE rail.
- Switched 48 VDC through relay to the PoE injector.
- Local 3.3 V rails on embedded boards.

---

## 7. Platform Host / Headless PC

The fanless headless PC is the central application and orchestration platform.

### 7.1 Roles

- Test executive.
- Manufacturing gateway.
- Cloud client.
- Recovery platform.
- Remote-support endpoint.
- Local service host.
- Data/log collection endpoint.

### 7.2 Software responsibility split

**React UI**

- Operator experience.
- Test selection.
- Status and result presentation.
- Configuration and workflow interaction.

**REST server**

- Control-plane API.
- Decouples user interface from hardware and test execution.
- Enables local and potentially remote control.

**Node.js test executor**

- Executes automated test sequences.
- Coordinates hardware and firmware interactions.
- Provides reusable test logic.
- Supports engineering, QA, and manufacturing modes.

**Cloud client / Azure connectivity**

- Firmware/software updates.
- Logs.
- Secrets.
- Diagnostics.
- Remote support.
- Future AI-assisted enhancements.

### 7.3 Sustainment concern

The PC is a critical single platform dependency because UI, REST services, automation, logs, cloud, diagnostics, USB, and Ethernet orchestration depend on it.

Required sustainment artifacts include:

- Recoverable system image.
- OS and dependency definition.
- Build and deployment automation.
- Configuration backup.
- Offline recovery procedure.
- Replacement-hardware criteria.

---

## 8. M1 Test Board

### 8.1 Platform role

The M1 Test Board owns the M1-specific validation and control scope. It supports both the M1 product and the M1 portion of MNPlus. The M1 functional portion is materially identical across those products.

### 8.2 Controller

- Teensy 4.1.

### 8.3 Capabilities captured from the schematic and discussion

- Target power on/off control.
- Boot-target selection.
- Serial/UART communications.
- RS-485 support.
- Firmware programming.
- Recovery and regeneration.
- Fixture-control functions.
- Operator-interface support.
- Battery-related control, loading, and measurements.
- Analog measurement and multiplexing.
- Tamper input handling.
- I2C/ribbon-cable connectivity.
- Product-interface signal access.
- Direct engineering connection through IDC.
- Production interface through product-specific wiring and pogo pins.

### 8.4 Direct IDC versus pogo-pin use

The board includes an IDC interface that can connect directly to the corresponding M1 board interface in an engineering setup.

In the production fixture:

- The product connects through a product-specific fixture plate.
- The electrical path is presented through pogo pins.
- Wiring maps the test board interfaces to the appropriate UUT points.

In the engineering bench configuration:

- Direct IDC connections can be used.
- Terminal blocks can expose signals.
- Pogo pins and enclosure are not required.

### 8.5 Documentation required

- Hardware specification.
- Functional block diagram.
- PCB CAD image placeholder, later replaced with 2D board image.
- Connector and pin-interface table.
- Power-domain table.
- Control-signal list.
- IDC interface-control document.
- Product mapping for M1 and MNPlus.
- Source schematic reference.
- Manufacturing files and BOM.
- Test and replacement strategy.

---

## 9. ACM Controller Test Board

### 9.1 Platform role

The ACM Controller Test Board is a reusable ACM ecosystem simulation and validation subsystem.

The board was developed for end-to-end automated testing supporting Elements, a cloud solution. The board provides broad coverage across ACM controllers and related products, not merely the limited ACM subset used by the current MNPlus fixture.

### 9.2 Controller and communications

- Teensy 4.1.
- Ethernet interface.
- FTDI/USB serial logging or service interface.
- RS-485 reader interfaces.

### 9.3 Reader simulation

The board simulates two reader channels.

Capabilities include:

- Dual OSDP reader simulation.
- Dual Wiegand reader simulation.
- Reader data and clock signals.
- Reader LED interaction.
- Reader buzzer interaction.
- Reader power control.
- RS-485 termination and direction control.

### 9.4 Supervised-input simulation

The board provides eight supervised-input simulation channels:

- SI1 through SI8.

The circuitry uses analog components to simulate the relevant supervised states required for controller validation. Formal documentation should enumerate the supported states based on firmware and electrical implementation, such as normal, active/alarm, open, short, and other configured resistance conditions when verified.

### 9.5 Relay/output validation

The board supports relay and output validation.

Observed schematic signals include:

- Relay 1 through Relay 10.

The platform can use these channels to verify controller relay activations and simulate/observe field behavior.

### 9.6 Additional simulation functions

- Cabinet tamper simulation.
- Power-fault simulation.
- Controller-power switching/control.
- Downstream enable/control signals.
- Product-family interface support.

### 9.7 Product coverage

- ACM controller lines.
- Door controllers.
- I/O expansion boards.
- ACM-related functions within MNPlus.
- Elements end-to-end automated testing.

### 9.8 Platform capability versus current implementation

The current MNPlus deployment uses only the subset of ACM capabilities required for ACM/MNPlus validation.

Using broader ACM functionality requires:

- A different product-specific fixture plate.
- More or differently mapped pogo pins.
- Additional wiring.

This is an implementation variation, not a redesign of the core ACM Controller Test Board.

### 9.9 Documentation required

- Hardware specification.
- Functional block diagram.
- 2D CAD image placeholder.
- Reader-interface description.
- OSDP and Wiegand interface tables.
- Supervised-input state description.
- Relay/output-validation description.
- Power and tamper simulation description.
- Supported-product matrix.
- Connector maps.
- Firmware interface summary.
- Source schematic reference.
- Manufacturing package and BOM.

---

## 10. SAM-E Ethernet Subsystem

### 10.1 Current role

- LenelS2 product manufactured in Saline.
- Three-port Ethernet switching within the platform.
- Receives a dedicated 5 V rail from the main power supply.
- Connects the ACM Test Board, PoE injector/UUT path, and host/network path as configured.

### 10.2 COVID redesign history

During COVID shortages, required components were unavailable or carried extremely long lead times.

Leo developed a redesign around available parts, including:

- STM32G1-family controller selection.
- Improved Micrel/Microchip Ethernet switch selection.
- Hardware redesign.
- Firmware and RTOS implications.
- Component research and sourcing.

The redesign was driven by buildability and supply continuity, not by unnecessary redesign.

### 10.3 Current decision

Paul preferred keeping the legacy board because the design is proven and already understood by Saline. Under current stable-production conditions, that is a reasonable risk-management decision.

### 10.4 Sustainment implication

The redesign work may remain useful as a future replacement path if the legacy board becomes unbuildable, unsupported, or obsolete.

Documentation should retain:

- Original SAM-E implementation requirements.
- Redesign source files if available.
- Functional equivalence criteria.
- Interface-control requirements.
- Replacement triggers.

---

## 11. Power Architecture

### 11.1 Primary supply

- 120 VAC input.
- Main switch/back-panel control.

### 11.2 Low-voltage supply

- 12.5 VDC rail for fixture/test-control electronics.
- 5 VDC rail for the SAM-E Ethernet switch.

### 11.3 PoE supply

- Separate 120 VAC to 48 VDC supply.
- 48 VDC relay control.
- Switched 48 VDC to the PoE injector.
- PoE power and Ethernet delivered to the UUT.

### 11.4 Review questions to document formally

- Power-up and shutdown sequence.
- Relay default state.
- Software authority over PoE switching.
- Isolation and grounding strategy.
- Fuse/protection requirements.
- Maximum current requirements.
- UUT fault containment.
- Factory safety and inspection requirements.

---

## 12. Network, USB, and Service Architecture

### 12.1 Ethernet

- Host PC connects to local network infrastructure.
- SAM-E provides local switching.
- ACM Controller Test Board uses Ethernet for test/control functions.
- PoE injector combines Ethernet and 48 VDC for the UUT.

### 12.2 USB

- Host PC connects through a USB hub.
- USB supports Teensy serial control.
- USB DFU supports firmware loading and recovery.
- USB serial console supports diagnostics.
- USB flash media may support recovery, configuration, images, or other controlled artifacts; exact function should be documented from the implementation.

### 12.3 Serial

The platform performs both Ethernet-based and serial-based testing. Serial access is a first-class capability, not merely a debug afterthought.

### 12.4 Documentation required

- Network topology.
- Port assignments.
- USB-device map.
- Serial-port map.
- Service-mode connections.
- Cloud connectivity assumptions.
- Offline operation requirements.

---

## 13. Mechanical and Interface Architecture

### 13.1 Production fixture

Observed characteristics:

- Custom machined/product-specific plate.
- Lever-actuated compression mechanism.
- Guided clamping.
- Product nest and registration features.
- Acrylic or protective cover.
- Dense pogo-pin interface.
- Enclosed electronics bay.
- Organized harnesses and power distribution.

### 13.2 Engineering bench

Observed characteristics:

- Open mounting plate.
- Fanless PC.
- Exposed test boards.
- Terminal blocks.
- Direct signal access.
- Ethernet and power subsystems.
- No production enclosure required.
- No production pogo-pin fixture required for direct engineering connections.

### 13.3 Product-specific adaptation

M1 and MNPlus require different plates because:

- The physical boards differ.
- Pogo-pin maps differ.
- Required wiring differs.

The common platform remains the same.

### 13.4 Factory deliverables

- Mechanical drawings.
- CAD source files.
- STEP files.
- DXF files.
- Plate drawings.
- Pogo-pin map.
- Wiring and harness drawings.
- Fastener list.
- Assembly torque/specification where applicable.
- Alignment and inspection criteria.

---

## 14. Platform Diagram State

The draw.io diagram is considered architecture-review ready after these updates:

- Title changed from a generic fixture layout to an EVM platform title.
- M1 Test Board labeled with M1 scope.
- ACM Test Board labeled with ACM scope.
- Headless PC included.
- Azure/cloud block included.
- Power rails shown, including the 5 V SAM-E rail.
- 48 V relay and PoE path shown.
- USB DFU and serial-console paths shown.
- Operator lever/status interface shown.
- Capability bullets added.

The diagram intentionally presents the platform at system level. Detailed pin maps, board CAD, and wiring belong in supporting documents.

### 14.1 Current capability bullets

Recommended compressed capability list:

- Unified Engineering, QA, Manufacturing, Recovery, and Technical Support Platform.
- Hardware-in-the-Loop product validation and automation.
- M1 and ACM functional simulation and validation.
- Automated hardware, firmware, and software testing.
- Ethernet, serial, USB, and PoE test infrastructure.
- Firmware programming, provisioning, recovery, and regeneration.
- Failure analysis, diagnostics, and remote support.
- Cloud-connected updates, diagnostics, logs, and secrets.
- React-based operator interface.
- REST API and Node.js automated test-execution framework.
- Common platform architecture supporting multiple products and product families.

ACM capabilities:

- OSDP reader simulation.
- Wiegand reader simulation.
- Reader power control.
- Eight supervised-input simulations.
- Relay/output validation.
- Door-controller validation.
- ACM-controller validation.
- I/O expansion-board validation.
- End-to-end automated ACM ecosystem testing.

Notes:

- The current MNPlus implementation uses the subset required for M1/MNPlus validation.
- Additional ACM capabilities can be utilized through product-specific plates, pogo-pin mappings, and wiring configurations.

---

## 15. Repository Architecture

Observed top-level structure:

```text
m1-platform/
├── AI/
├── components/
├── doc/
├── scripts/
├── setup/
├── README.md
└── READMEConfig.md
```

Observed components:

```text
components/
├── m1-operator-ui/
├── m1-rest-server/
├── m1testBoardFw/
├── m1tfc/
├── acm-testboard-fw/
├── stm32mp1-baremetal/
└── tfcroncli/
```

This structure demonstrates a platform ecosystem spanning cloud, UI, REST services, embedded firmware, bare-metal work, test execution, automation, and CLI tools.

---

## 16. Required Documentation Repository Structure

Recommended structure:

```text
doc/
├── Architecture/
│   ├── Platform/
│   ├── Hardware/
│   │   ├── M1-Test-Board/
│   │   ├── ACM-Controller-Test-Board/
│   │   ├── SAM-E-Subsystem/
│   │   ├── Power/
│   │   ├── Network-and-PoE/
│   │   ├── Mechanical/
│   │   └── Fixture-Interface/
│   ├── Firmware/
│   └── Software/
├── Assembly/
├── Manufacturing/
├── Operations/
├── Validation/
├── Sustainment/
└── ICD/
```

### 16.1 Architecture / Platform

- EVM Platform Overview.
- EVM Platform Capabilities.
- EVM Hardware Architecture.
- Engineering vs Production Configurations.
- Product Coverage Matrix.
- Platform Evolution.

### 16.2 Architecture / Hardware

- M1 Test Board Hardware Specification.
- ACM Controller Test Board Hardware Specification.
- SAM-E subsystem description.
- Power Architecture.
- Network and PoE Architecture.
- Mechanical Architecture.
- Fixture Interface Architecture.

### 16.3 Firmware — future

- M1 Test Board Firmware Architecture.
- ACM Controller Test Board Firmware Architecture.
- Firmware interfaces.
- Build and release process.

### 16.4 Software — future

- React Operator UI Architecture.
- REST Server Architecture.
- Node.js Test Framework Architecture.
- Cloud Client Architecture.
- CLI and automation documentation.

### 16.5 Assembly

- Engineering Platform Assembly Guide.
- Production Fixture Assembly Guide.
- Wiring drawings.
- Harness drawings.
- Mechanical drawings.
- Inspection criteria.

### 16.6 Manufacturing

- Manufacturing deployment guide.
- Provisioning process.
- Factory validation procedure.
- Factory Acceptance Test.
- Manufacturing release checklist.

### 16.7 Operations — future

- Operator guide.
- Service guide.
- Recovery procedures.
- Troubleshooting guide.

### 16.8 Validation

- Validation strategy.
- Regression strategy.
- Product coverage matrix.
- Qualification reports.
- Test-coverage reports.

### 16.9 Sustainment

- Obsolescence-management plan.
- Critical-component registry.
- Replacement strategies.
- Toolchain preservation.
- Lifecycle risk register.
- Periodic sustainment review.

### 16.10 Interface-Control Documents

- M1 product interface.
- MNPlus product interface.
- IDC interface.
- Pogo-pin maps.
- Reader interfaces.
- Power interfaces.
- Ethernet interfaces.
- USB/serial interfaces.
- Manufacturing interfaces.

---

## 17. Formal Documents to Generate First

### Document 1 — EVM Platform Overview

Purpose:

- Explain what EVM is.
- Explain why EVM exists.
- Explain lifecycle use cases.
- Show major subsystems.
- Establish that the production fixture is one deployment.

Suggested sections:

1. Purpose.
2. Scope.
3. Platform vision.
4. Supported lifecycle functions.
5. Supported products.
6. Major subsystems.
7. Engineering and production deployments.
8. Architecture overview.
9. Documentation map.
10. Sustainment statement.

### Document 2 — EVM Hardware Architecture

Suggested sections:

1. Scope and exclusions.
2. System block diagram.
3. Hardware decomposition.
4. Power architecture.
5. Network and PoE architecture.
6. USB and serial architecture.
7. M1 Test Board role.
8. ACM Controller Test Board role.
9. Engineering direct-access interface.
10. Production fixture interface.
11. Product-specific adaptations.
12. Safety and maintainability considerations.
13. Interfaces to firmware/software.
14. Sustainment considerations.

### Document 3 — M1 Test Board Hardware Specification

Suggested sections:

1. Purpose and scope.
2. Functional architecture.
3. CAD/image placeholder.
4. Controller and power.
5. Interfaces.
6. Boot and target control.
7. Analog measurements.
8. Battery-related functions.
9. IDC interface.
10. Production pogo-pin mapping approach.
11. Supported products.
12. Manufacturing artifacts.
13. Sustainment requirements.

### Document 4 — ACM Controller Test Board Hardware Specification

Suggested sections:

1. Purpose and scope.
2. Functional architecture.
3. CAD/image placeholder.
4. Controller and communications.
5. Dual reader simulation.
6. OSDP interfaces.
7. Wiegand interfaces.
8. Reader power/LED/buzzer behavior.
9. Supervised-input simulation.
10. Relay/output validation.
11. Power-fault and cabinet-tamper simulation.
12. Supported products.
13. Full capability versus current MNPlus subset.
14. Manufacturing artifacts.
15. Sustainment requirements.

### Document 5 — Factory Production Fixture Assembly Guide

Suggested sections:

1. Purpose and controlled configuration.
2. Safety.
3. Required parts and BOM.
4. Mechanical components.
5. Electrical components.
6. Wiring and harness installation.
7. Board installation.
8. Power-supply installation.
9. Fixture-plate and pogo-pin setup.
10. Cable routing and strain relief.
11. Initial power-up.
12. Software/image loading reference.
13. Verification and Factory Acceptance Test.
14. Inspection checklist.
15. Serialization and release records.

### Document 6 — Twenty-Year Sustainment Plan

Suggested sections:

1. Service-life requirement.
2. Configuration baseline.
3. Critical components.
4. Obsolescence monitoring.
5. Approved alternate process.
6. Redesign triggers.
7. Toolchain preservation.
8. Source and binary preservation.
9. Replacement-PC strategy.
10. Interface preservation.
11. Periodic review schedule.
12. End-of-life and technology-refresh process.

---

## 18. Factory Documentation Requirements

The factory builds the box and performs the assembly. The factory package must be actionable and controlled, not a high-level architecture narrative.

Required artifacts:

- Controlled BOM.
- Approved manufacturer part numbers.
- Alternate parts where approved.
- Mechanical drawings.
- Enclosure drawing.
- Plate drawing for each UUT configuration.
- Pogo-pin part numbers and placement map.
- Wiring diagram.
- Harness drawings and lengths.
- Connector/pin tables.
- Terminal-block map.
- Power-distribution diagram.
- Assembly sequence.
- Cable routing and strain-relief instructions.
- Torque/fastener guidance where applicable.
- Photos or CAD views at key assembly stages.
- Labeling requirements.
- PC loading/configuration reference.
- Initial power-up checks.
- Factory Acceptance Test.
- Final inspection and release checklist.

The factory should be able to build and verify the platform without requiring undocumented knowledge from Leo.

---

## 19. Twenty-Year Service-Life and Sustainment

Paul's requirement is that the platform remain in service for approximately twenty years.

### 19.1 Core reality

It is unlikely that all electronics, specific components, computing hardware, operating systems, and toolchains will remain unchanged and available for twenty years.

The sustainment design goal is therefore not “freeze every component.” It is:

> Preserve the functions, interfaces, requirements, source, manufacturing knowledge, and validation methods needed to repair or redesign subsystems over time.

### 19.2 High-risk components

Examples requiring lifecycle monitoring:

- Teensy 4.1.
- SAM-E legacy components.
- Microcontrollers and processors.
- Ethernet switches and PHYs.
- RS-485 transceivers.
- Regulators and power components.
- PoE injector.
- Fanless PC.
- USB hub.
- Connectors and pogo pins.
- Mechanical fixture components.

### 19.3 Required source preservation

Hardware:

- Native design projects.
- Libraries.
- Schematics.
- PCB layouts.
- Gerbers.
- Pick-and-place.
- BOM.
- Assembly drawings.
- CAD and manufacturing drawings.

Firmware/software:

- Source repositories.
- Submodule/dependency state.
- Build scripts.
- Toolchain versions.
- Reproducible build environments.
- Release binaries.
- Installation packages.
- Recovery images.
- Secrets-management procedures without embedding live secrets.

### 19.4 Interface preservation

ICDs are critical because future implementations may change while required interfaces must remain stable.

Each ICD should capture:

- Signal name.
- Direction.
- Voltage/current level.
- Protocol.
- Timing.
- Connector and pin.
- Default state.
- Fault behavior.
- Test/validation method.

### 19.5 Obsolescence process

Recommended process:

1. Maintain a critical-component register.
2. Review lifecycle status at least annually.
3. Track last-time-buy notices.
4. Identify candidate alternates early.
5. Define functional replacement requirements.
6. Build validation tests before redesign.
7. Preserve known-good golden units.
8. Document redesign and qualification decisions.

---

## 20. Source Artifacts Reviewed or Available

### Schematics

- M1 Test Board schematic PDF.
- ACM Controller Test Board schematic PDF.
- M1-3200 product schematic PDF.
- MNPlus product schematic PDF.

### Drawings and images

- EVM draw.io system diagram.
- 2D CAD views available for boards.
- Production fixture photographs.
- Engineering bench photographs.

### Repository

- Cloud client.
- Operator UI.
- REST server.
- M1 board firmware.
- ACM board firmware.
- STM32MP1 bare-metal work.
- Test framework.
- CLI automation.
- Scripts, setup, and current documentation.

---

## 21. Known Documentation Boundaries

### In immediate scope

- Platform Overview.
- Platform Capabilities.
- Hardware Architecture.
- M1 Test Board spec.
- ACM Controller Test Board spec.
- Factory assembly package.
- Sustainment foundations.

### Not yet in immediate scope

- Full software architecture.
- Full firmware architecture.
- Detailed operational procedures.
- Complete validation test specifications.

Those areas should already have reserved directory locations so future documents can be added without restructuring the repository.

---

## 22. Important Corrections and Lessons

1. The EVM is not merely a test fixture.
2. The production enclosure is one implementation of the platform.
3. Engineering and production use the same core architecture but different interface layers.
4. M1 and MNPlus require different plates/pogo mappings because the physical boards differ.
5. The ACM board has much broader capability than the ACM subset used in MNPlus.
6. The M1 Test Board provides direct IDC engineering connectivity as well as production-interface support.
7. The 5 V SAM-E rail must be shown in the power architecture.
8. Draw.io section/background boxes must never become electrical endpoints.
9. Visual board labels are authoritative even if internal XML IDs are confusing.
10. Valid Word files must be generated as real DOCX packages and rendered before delivery.
11. A directory skeleton is not documentation.
12. A true restore point must preserve reasoning, not just headings.

---

## 23. Open Technical Questions

1. Exact UUT pogo-pin signal list for M1.
2. Exact UUT pogo-pin signal list for MNPlus.
3. Exact USB flash-drive role.
4. Formal definition of all supported supervised-input states.
5. Exact division of relay/output validation channels used by each product.
6. PoE switching control authority and default safety state.
7. Full network-addressing and port model.
8. Offline operation requirements.
9. PC recovery-image and replacement-hardware requirements.
10. Calibration requirements, if any.
11. Factory acceptance limits and expected measurements.
12. Required traceability records.
13. Critical-component ownership and lifecycle-review frequency.
14. Final document numbering and revision system.

---

## 24. Recommended Documentation Priority

1. EVM Platform Overview.
2. EVM Hardware Architecture.
3. Engineering vs Production Configurations.
4. M1 Test Board Hardware Specification.
5. ACM Controller Test Board Hardware Specification.
6. Production Fixture Assembly Guide.
7. Wiring and Interface Package.
8. Factory Acceptance Test.
9. Product Coverage Matrix.
10. Twenty-Year Sustainment Plan.
11. Firmware Architecture.
12. Software Architecture.
13. Operations and Service Documentation.

---

## 25. Final Architecture Conclusions

1. The EVM is a platform, not a single-purpose fixture.
2. The architecture was designed at system level before implementation.
3. The platform unifies engineering, QA, manufacturing, recovery, and support.
4. The M1 Test Board encapsulates M1-specific control and validation.
5. The ACM Controller Test Board is a reusable ACM ecosystem simulator.
6. Product-specific plates, pogo maps, IDC connections, and wiring expose selected platform capabilities.
7. The headless PC provides the application, automation, cloud, recovery, and remote-support layer.
8. The SAM-E and PoE subsystems provide controlled network and power infrastructure.
9. The engineering bench and production fixture are two deployments of the same architecture.
10. Formal factory documentation is necessary because Saline/factory personnel build the enclosure and perform assembly.
11. Twenty-year service life requires obsolescence planning, interface preservation, reproducible builds, and complete source/manufacturing artifacts.
12. The documentation package should be organized Platform → Subsystem → Implementation, not as an unstructured collection of board files.

---

## 26. Future Restore Prompt

> Read `doc/Architecture/Platform/Context/EVM_Architecture_Authoring_Context_2026-07-25.md` (this file) as the authoritative state of the M1/MNPlus Unified Engineering, Validation and Manufacturing Platform. Use the documented platform terminology, subsystem responsibilities, engineering-versus-production distinction, factory-documentation requirements, repository structure, and twenty-year sustainment model. Generate documentation beginning with Platform Overview and Hardware Architecture, then board specifications and factory assembly. Do not reduce EVM to a test fixture. Do not invent missing interfaces; preserve listed open questions until Leo supplies the authoritative details.
