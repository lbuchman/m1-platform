**M1 Test Board Hardware Specification**

*M1-scope control and validation subsystem*

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

The M1 Test Board provides M1-specific control, measurement, programming, recovery, and product-interface functions for both M1 and the M1 scope of MNPlus.

# 2. Board Image

\[Insert controlled 2D CAD board view here\]

# 3. Functional Summary

- Teensy 4.1 control processor

- Target power on/off control

- Boot-target selection

- Serial/UART and RS-485 communication

- Firmware programming and product recovery

- Battery-control and measurement functions

- Analog multiplexing and measurement

- Tamper and control-signal access

- IDC/ribbon interface

- Production fixture interface through wiring and pogo pins

# 4. Interface Summary

  ----------------------------------------------------------------------------------------------------------------
  **Interface**           **Purpose**                                  **Configuration**
  ----------------------- -------------------------------------------- -------------------------------------------
  IDC / ribbon            Direct product and test-board connectivity   Engineering and controlled fixture wiring

  USB serial              Controller command, debug, and automation    Engineering / QA / production

  RS-485                  Product or test communication                As required by M1 scope

  Power control           Target 12 V and related rails                All deployments

  Pogo-pin mapping        Product-specific electrical access           Production fixture
  ----------------------------------------------------------------------------------------------------------------

# 5. Engineering and Production Use

Engineering may connect directly through the IDC interface and terminal blocks. Production uses a product-specific fixture plate and pogo-pin mapping. The difference is implementation and workflow, not a different board architecture.

# 6. Verification Requirements

- Verify all supply rails before target connection

- Verify boot-target control

- Verify target power switching

- Verify serial and RS-485 paths

- Verify analog measurement channels

- Verify IDC pinout against the controlled ICD

- Verify production pogo-pin map and contact continuity

# 7. Sustainment Data Required

- Native schematic and PCB source

- BOM and approved alternates

- Gerber and pick-and-place package

- Controller firmware source and build environment

- IDC and pogo-pin ICDs

- Golden-board acceptance test

- Critical-component lifecycle list

# 8. Source Schematic

See Source-Schematics/M1_Test_Board_Schematic.pdf in this package.
