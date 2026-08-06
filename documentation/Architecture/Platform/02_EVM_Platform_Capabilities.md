**EVM Platform Capabilities**

*Capability baseline for engineering and manufacturing stakeholders*

Version 1.0 \| July 25, 2026\
Owner: Leo Buchman\
Status: Initial controlled draft

  -------------------------------------------------------------------------------------------
  Document Type                       Capability Specification
  ----------------------------------- -------------------------------------------------------
  Platform                            M1/MNPlus EVM

  Scope                               Hardware / architecture

  Source Baseline                     Schematics, platform diagram, physical configurations
  -------------------------------------------------------------------------------------------

# 1. Platform Capability Summary

- Unified Engineering, QA, Manufacturing, Recovery, and Technical Support Platform

- Hardware-in-the-Loop product validation and automation

- M1 and ACM functional simulation and validation

- Automated hardware, firmware, and software testing

- Ethernet, serial, USB, RS-485, OSDP, Wiegand, and PoE test infrastructure

- Firmware programming, provisioning, recovery, and regeneration

- Failure analysis, diagnostics, logs, and remote support

- React-based operator interface

- REST control services and Node.js automated test execution

- Common platform architecture supporting multiple products and product families

# 2. M1-Scope Capabilities

- M1 and MNPlus M1-subsystem validation

- Boot-target selection

- Target power control

- Serial-console and programming access

- Battery-related control and measurements

- Analog measurement and channel selection

- Tamper and product-interface access

- Direct IDC engineering connectivity

- Production pogo-pin connectivity through product-specific wiring

# 3. ACM / ACM-Scope Capabilities

- Dual OSDP reader simulation

- Dual Wiegand reader simulation

- Reader power, LED, and buzzer interaction

- Eight supervised-input simulation channels

- Relay/output activation validation

- Cabinet-tamper simulation

- Power-fault simulation

- ACM controller validation

- Door-controller validation

- I/O expansion-board validation

- End-to-end automated ACM ecosystem testing

# 4. Capability Versus Product Implementation

A product fixture exposes the subset of platform capabilities required by that product. M1 and MNPlus use different physical plates and pogo-pin maps. Broader ACM coverage requires a different plate, additional pogo-pin assignments, and additional wiring; the common ACM simulation electronics remain unchanged.

# 5. Known Capability Boundaries

- Exact supervised-input states must be confirmed from firmware and validation definitions

- Exact USB flash-drive use must be documented from implementation

- Product-specific pin maps belong in controlled ICDs and assembly drawings

- Detailed software, firmware, and operational procedures are separate documents
