**EVM Hardware Architecture**

*System-level hardware decomposition and interfaces*

Version 1.0 \| July 25, 2026\
Owner: Leo Buchman\
Status: Initial controlled draft

  -------------------------------------------------------------------------------------------
  Document Type                       Hardware Architecture
  ----------------------------------- -------------------------------------------------------
  Platform                            M1/MNPlus EVM

  Scope                               Hardware / architecture

  Source Baseline                     Schematics, platform diagram, physical configurations
  -------------------------------------------------------------------------------------------

# 1. Scope

This document defines the physical hardware architecture of the EVM. Detailed software behavior, firmware internals, and operating procedures are excluded except where needed to explain interfaces.

# 2. Architecture Diagram

![](../../Images/03_EVM_Hardware_Architecture_image1.png){width="7.0in" height="2.563115704286964in"}

*Figure 1 - EVM hardware architecture*

# 3. Power Architecture

  ----------------------------------------------------------------------------------------------------------------
  **Source**              **Destination**                                 **Function**
  ----------------------- ----------------------------------------------- ----------------------------------------
  120 VAC                 12.5 V / 5 V supply                             Fixture/test electronics power

  12.5 V rail             M1 Test Board and associated test electronics   Controller and product-interface power

  5 V rail                SAM-E three-port Ethernet switch                Network subsystem power

  120 VAC                 48 V supply                                     PoE power source

  48 V supply             48 V relay                                      Controlled PoE enable path

  48 V relay              PoE injector                                    Switched 48 VDC

  PoE injector            UUT through product interface                   Ethernet plus power
  ----------------------------------------------------------------------------------------------------------------

# 4. Network and Service Architecture

- Headless PC provides Ethernet and USB control paths

- SAM-E provides local Ethernet switching

- Mercury Controller Test Board participates in network-based testing

- PoE injector combines Ethernet and controlled 48 VDC

- USB hub exposes Teensy serial, DFU, and service-console paths

- Serial-based testing is a first-class validation path alongside Ethernet

# 5. Hardware Subsystem Responsibilities

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Subsystem**                       **Responsibilities**
  ----------------------------------- ---------------------------------------------------------------------------------------------------------------------------------
  M1 Test Board                       M1-scope control, target power, boot selection, measurements, programming/recovery, direct IDC and production interface support

  Mercury Controller Test Board       Reader simulation, supervised-input simulation, relay/output validation, tamper/power-fault simulation

  SAM-E                               Three-port Ethernet switching and test-network distribution

  Fixture mechanics                   Product registration, compression, repeatable pogo-pin engagement, operator safety

  Engineering interface               Terminal blocks, direct IDC, accessible debug and service connections
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 6. Safety and Review Items

- Define 48 V relay default and fail-safe state

- Document fuse/protection ratings and grounding

- Define maximum currents for all power rails

- Document connector keying and prevention of incorrect assembly

- Define initial power-up and acceptance measurements

# 7. Source References

- M1 Test Board schematic: Architecture/Hardware/M1-Test-Board/Source-Schematics/M1_Test_Board_Schematic.pdf

- Mercury Controller Test Board schematic: Architecture/Hardware/Mercury-Controller-Test-Board/Source-Schematics/Mercury_Controller_Test_Board_Schematic.pdf
