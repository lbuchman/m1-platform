**ACM Controller Test Board Hardware Specification**

*Reusable ACM ecosystem simulation and validation subsystem*

Version 1.0 \| July 25, 2026\
Owner: Leo Buchman\
Status: Initial controlled draft

  -------------------------------------------------------------------------------------------
  Document Type                       Board Hardware Specification
  ----------------------------------- -------------------------------------------------------
  Platform                            M1/MNPlus EVM

  Scope                               Hardware / architecture

  Source Baseline                     Schematics, platform diagram, physical configurations
  -------------------------------------------------------------------------------------------

# 1. Purpose

The ACM Controller Test Board provides reusable simulation and validation for ACM controllers, door controllers, I/O boards, and the ACM scope used by MNPlus. The board was developed to support automated end-to-end Elements validation.

# 2. Board Image

\[Insert controlled 2D CAD board view here\]

# 3. Functional Summary

- Teensy 4.1 controller

- Ethernet connectivity

- FTDI/USB serial logging and service access

- Two reader simulation channels

- Dual OSDP simulation

- Dual Wiegand simulation

- Reader power, LED, and buzzer interaction

- 8 supervised channels

- Relay/output activation validation

- Cabinet-tamper simulation

- Power-fault simulation

- Controller power control

- Downstream control

# 4. Reader Simulation

  ----------------------------------------------------------------------------------------
  **Channel**             **Protocols**           **Signals / functions**
  ----------------------- ----------------------- ----------------------------------------
  Reader 1                OSDP and Wiegand        RS-485, data/clock, LED, buzzer, power

  Reader 2                OSDP and Wiegand        RS-485, data/clock, LED, buzzer, power
  ----------------------------------------------------------------------------------------

# 5. Supervised Inputs

8 analog supervised channels (SI1-SI8) are implemented. The controlled validation specification must list the exact resistance/state combinations recognized by firmware and the expected controller interpretation.

# 6. Relay and Output Validation

The schematic exposes Relay1 through Relay10 paths for validating controller output activation and related cabinet/power behavior. Product-specific harnesses determine which channels are used in a given deployment.

# 7. Supported Product Coverage

- ACM controller families

- ACM door controllers

- ACM I/O expansion boards

- MNPlus ACM scope

- Elements end-to-end use cases

# 8. Current MNPlus Subset

The current MNPlus fixture uses the subset required for ACM/MNPlus validation. Full ACM capability can be exposed through a different plate, expanded pogo-pin mapping, and additional wiring. Core board redesign is not required.

# 9. Sustainment Data Required

- Native schematic and PCB source

- BOM and approved alternates

- Gerber and pick-and-place package

- Firmware source and reproducible build environment

- Reader, supervised-channel, and relay ICDs

- Golden-board acceptance test

- Critical-component lifecycle list

# 10. Source Schematic

See Source-Schematics/ACM_Controller_Test_Board_Schematic.pdf in this package.
