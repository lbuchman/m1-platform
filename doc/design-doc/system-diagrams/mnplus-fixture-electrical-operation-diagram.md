# mnplus Fixture Electrical and Operation Diagram

## Scope
This diagram captures the fixture mechanics and primary power flow described so far.

## Electrical Block Diagram

```mermaid
flowchart LR
    AC[120V AC Input] --> SW[Back Panel Main Switch]
    SW --> PSU[Internal Power Supply]
    PSU --> DC12[12V DC Rail]
    PSU --> DC5[5V DC Rail]
    SW --> PSU48[120V AC to 48V DC Power Supply]
    ETH[Back Panel Ethernet Jack]
    USBB[Back Panel USB-B Standard Jack]

    subgraph Fixture[Fixture Box]
      PSU
      DC12
      DC5
      PSU48
      ETH
      USBB
      USBSW[USB Switch]
      SAME[SAM-E 3-Port Ethernet Switch]
      RELAY[48V Relay Control]
      POE[Ethernet Power Injector]
      POGO[Pogo Pin Bed on Base Plate]
      MNT[Mounting Hardware]
      COV[Hinged Cover]
      UUT[UUT Board: mnplus]
    end

    USBB --> USBSW
    ETH --> SAME
    SAME -- Ethernet input --> POE
    PSU48 --> RELAY
    RELAY -- switched 48V DC --> POE
    POE -- PoE output over pogo pins --> POGO

    COV -- closes and applies force --> UUT
    UUT -- test points contact --> POGO
    MNT -- aligns and secures --> UUT
```

## Operation Sequence Diagram

```mermaid
flowchart TD
    S1[Open Cover] --> S2[Place mnplus UUT on Fixture Plate]
    S2 --> S3[Align with Mounting Hardware]
    S3 --> S4[Close Cover]
    S4 --> S5[Board Pressed Down]
    S5 --> S6[Test Points Contact Pogo Pins]
  S6 --> S7[Toggle Back Panel Switch ON]
  S7 --> S8[120V AC Feeds Internal PSUs]
  S8 --> S9[Main PSU Generates 12V DC and 5V DC]
  S9 --> S10[48V PSU Generates 48V DC]
  S10 --> S11[Enable Relay to Feed 48V to PoE Injector]
  S11 --> S12[SAM-E Switch Feeds Ethernet to PoE Injector]
  S12 --> S13[PoE Injector Feeds UUT over Pogo Pins]
  S13 --> S14[Fixture Ready for Test Steps]
```

## Notes
- This version models only the elements provided so far.
- Back panel includes an Ethernet jack and USB-B standard jack.
- USB-B jack routes to an internal USB switch.
- Ethernet jack routes to an internal SAM-E 3-port Ethernet switch.
- PoE injector receives Ethernet from the SAM-E switch and switched 48V DC through a relay.
- PoE injector output goes to the UUT through pogo-pin connections.
- Next revision can add controller, signal routing, measurements, and pass/fail indication.
