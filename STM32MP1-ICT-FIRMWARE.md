# STM32MP1 ICT Firmware

`components/stm32mp1-baremetal` is the STM32MP1 bare-metal firmware component
used by ICT. ICT must execute without Linux running on the target: SDRAM is a
test subject, so Linux cannot own, initialize, or use the memory under test.
The component is therefore a standalone firmware repository, separate from the
Snap-packaged host-side tools.

Its build requires Arm GNU Toolchain `12.2.MPACBTI-Rel1` at:

```text
/opt/arm-gnu-toolchain-12.2.mpacbti-rel1-x86_64-arm-none-eabi
```

This `arm-none-eabi` toolchain is required only by
`components/stm32mp1-baremetal`. It is not the Node toolchain used by Snap
components or the PlatformIO toolchain used by Teensy firmware. GNU Make and
Python 3 are also required.

Build the FSBL from the component root:

```bash
cd components/stm32mp1-baremetal
source env.sh
arm-none-eabi-gcc --version
make clean
make
```

`env.sh` must be sourced in the same shell as `make`; it adds the required ARM
compiler and binutils to `PATH`.

The STM32MP1 component builds from its root `Makefile`; its active firmware
layout is `src/`, `include/`, `third-party/`, and `tools/`. A successful build
produces:

```text
build/fsbl.elf
build/fsbl.bin
build/fsbl.stm32
```

`build/fsbl.stm32` is the STM2 BootROM image to use for the target. It includes
the BootROM header and checksum generated from the `.bin` artifact; do not use
the `.elf` or `.bin` in its place.

`make` only builds the image. `make install` stages the built FSBL at
`/var/m1mtf/fsbl.stm32` for the normal ICT command path. `make load` is a
separate interactive SD-media operation that writes the first two boot
partitions; run it only after the approved provisioning path and target device
identity have been verified.
