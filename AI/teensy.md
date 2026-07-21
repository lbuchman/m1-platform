# Mercury Test Board Firmware (Teensy) — RS485 Reader Investigation

This file tracks the ongoing investigation into `components/mercury-testboard-fw` (Teensy 4.1) RS485 reader behavior. Keep entries factual; separate observed facts from inference per `AI/calibration.md`.

## Problem

After a real RS485 test command (`testrd1rs485`/`testrd2rs485`, run from the M1/MNP board side, `components/stm32mp1-baremetal`), the Mercury Teensy board enters continuous ~1kHz self-sustaining RS485 retransmission that never stops. Confirmed (bench-observed) to originate in this Teensy firmware, not the M1-side firmware. Root cause not yet found.

A separate, newer symptom: the Teensy has entered a boot-time reboot loop. Not yet root-caused or confirmed reproducible.

## Confirmed Facts

- `Reader::osdpTask` in `include/reader.hpp` is an unconditional 1ms `TaskScheduler` task: `if(pins.serial.available()){ char c = pins.serial.read(); pins.serial.write(c); }` — echoes any received byte back out immediately, no filtering or state check. Matches the observed ~1kHz (999.927Hz measured) retransmission frequency.
- Physical RS485 bus length is 8". Round-trip propagation time (~25-30ns) is far shorter than one UART bit period at 115200 baud (~8.68us) — cable-reflection ringing cannot explain a 1ms-cadence oscillation. **Ruled out.**
- `AMALOG_MUX_EN` (defined in `include/hw.h`) = digital pin 31 = the same physical pin as `Rs485TermPin` (defined separately in `src/init.cpp`). Two symbolic names, one pin.
- This pin drives U2 (`SN74LVC2G66DCUR`) analog switch, gating the 120R RS485 end-of-line termination resistors shared by both readers (per Schematic_Controller-Test-Board-Rev-8, sheet 2/6).
- TI datasheet for `SN74LVC2G66`: control pins `1C`/`2C`, logic `L = OFF (disconnected), H = ON (connected)`.
- `setupFw()` in `src/init.cpp` hardcodes this pin `OUTPUT`/`LOW` at boot and never touches it again anywhere in committed source — termination is statically disconnected in every build as shipped.
- **Tested and ruled out (2026-07-21):** a bench experiment added `pinMode(AMALOG_MUX_EN, OUTPUT); digitalWrite(AMALOG_MUX_EN, HIGH);` to the `Reader` constructor to force termination ON. This did **not** fix the runaway retransmission. Change was reverted (`git checkout -- include/reader.hpp`). Do not re-propose "missing termination" as the sole root cause without new evidence.
- `mainLoop()` (in `src/init.cpp`) is simply `while(true) ts.execute();` — no other background mechanism.
- `enableWatchdog()` and `watchDogTask.enable()` (2-second expiry, petted every ~666ms) run in `setupFw()` **before** `boardInit()`, `persistentDataInit()`, and `initNetworking()`. If any of those blocks longer than ~2s (e.g. Ethernet link/DHCP with no cable connected), the watchdog would fire mid-boot and reset in a loop. This is a plausible, code-grounded mechanism for the newly observed reboot loop — **not yet confirmed**.

## Open Questions

- Is the reboot loop new, or was it present before this session's changes? Does it occur at power-up before any serial command, or only after running a reader test?
- Does the runaway retransmission also occur on Reader 1 (U1), or was that an oscilloscope probe/labeling mix-up during an earlier capture? (Unresolved contradiction from an earlier bench session — never confirmed which reader was under test during a specific scope capture.)
- Does U2's actual switch-output node (feeding the 120R resistors) really toggle when `AMALOG_MUX_EN`/`Rs485TermPin` changes state? Not yet verified with a scope/meter directly on U2.

## Bench/Build Notes

- Build and flash: `cd components/mercury-testboard-fw && pio run -t upload`.
- `platformio.ini` had no `upload_protocol` set, defaulting to `teensy-gui` which fails on this headless bench ("Unable find Teensy Loader"). Added `upload_protocol = teensy-cli` to match `m1testBoardFw`.
- Flashing this board intermittently fails on the first attempt ("error writing to Teensy" / HalfKay write failure) and succeeds on retry — expect to run `pio run -t upload` twice, same as `m1testBoardFw`.
- A bench experiment temporarily commented out `osdpTask.enable();` in `include/reader.hpp` to isolate whether the echo task itself is responsible for the reboot loop / retransmission. That change was reverted; `include/reader.hpp` currently matches the committed source (only `platformio.ini`'s `upload_protocol` line remains locally modified). Result of that experiment was not conclusively evaluated before reverting.
