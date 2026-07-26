**EVM Twenty-Year Sustainment Plan**

*Lifecycle, obsolescence, source preservation, and replacement strategy*

Version 1.0 \| July 25, 2026\
Owner: Leo Buchman\
Status: Initial controlled draft

  -------------------------------------------------------------------------------------------
  Document Type                       Sustainment Plan
  ----------------------------------- -------------------------------------------------------
  Platform                            M1/MNPlus EVM

  Scope                               Hardware / architecture

  Source Baseline                     Schematics, platform diagram, physical configurations
  -------------------------------------------------------------------------------------------

# 1. Requirement

The EVM is expected to remain supportable for approximately twenty years. The sustainment objective is to preserve required functions and interfaces even when individual electronic, mechanical, computing, operating-system, and toolchain components require replacement.

# 2. Sustainment Principles

- Preserve native design sources, not only PDFs

- Preserve controlled interfaces and validation criteria

- Maintain reproducible firmware and software builds

- Track critical-component lifecycle status

- Keep golden hardware and known-good release images

- Treat redesign as expected lifecycle work, not exceptional failure

- Document architecture rationale so replacements preserve function

# 3. Critical Asset Register

  ----------------------------------------------------------------------------------------------------------------------------------------------
  **Asset class**         **Examples**                                            **Required preservation**
  ----------------------- ------------------------------------------------------- --------------------------------------------------------------
  Hardware design         M1 board, Mercury board, SAM-E, power, harnesses        Native CAD, libraries, BOM, manufacturing outputs

  Mechanical              Enclosure, plate, pogo bed, brackets                    CAD, STEP, DXF, drawings, materials

  Firmware                M1 and Mercury test-board firmware                      Source, compiler/toolchain, build scripts, release binaries

  Software                React UI, REST server, Node.js executor, cloud client   Source, locked dependencies, install/deploy process

  Host platform           Fanless PC and OS image                                 Recovery image, replacement criteria, drivers, configuration

  Interfaces              IDC, pogo pins, reader, Ethernet, USB, power            Controlled ICDs and pin maps

  Validation              Golden units, acceptance tests, regression tests        Procedures, expected results, retained reference units
  ----------------------------------------------------------------------------------------------------------------------------------------------

# 4. Obsolescence Process

1\. Maintain a critical-component list with manufacturer lifecycle status

2\. Review lifecycle status at least annually

3\. Record EOL/NRND and last-time-buy notices

4\. Identify candidate sources or alternate components

5\. Define function and interface requirements before replacement

6\. Prototype and validate replacements using the EVM regression suite

7\. Update sources, BOM, manufacturing files, and acceptance tests

8\. Retain the superseded baseline and migration rationale

# 5. Known Long-Term Risks

- Teensy 4.1 availability

- Legacy SAM-E component availability

- Ethernet switch and PHY availability

- RS-485 transceiver availability

- Power-supply and PoE component availability

- Fanless PC lifecycle and storage failure

- Linux/OS and web-package ecosystem changes

- Cloud service and authentication changes

- Loss of supplier/manufacturing knowledge

- Knowledge concentration in one engineer

# 6. Review Cadence

  -------------------------------------------------------------------------------------------------------------
  **Review**                        **Recommended cadence**             **Output**
  --------------------------------- ----------------------------------- ---------------------------------------
  Component lifecycle               Annual                              Updated risk and alternate list

  Build reproducibility             Annual and at every major release   Verified clean build record

  Factory rebuild exercise          Every 2-3 years                     Confirmed manufacturing package

  PC recovery drill                 Annual                              Verified recovery image and procedure

  Architecture/sustainment review   Every 2 years                       Technology refresh decisions

  Golden-unit verification          Annual                              Known-good reference status
  -------------------------------------------------------------------------------------------------------------

# 7. Immediate Actions

- Collect native board design sources and libraries

- Collect mechanical CAD and plate drawings

- Create complete BOMs and manufacturing outputs

- Define all ICDs

- Create factory acceptance and golden-unit tests

- Preserve host-PC image and deployment process

- Create critical-component register

- Assign document and sustainment ownership
