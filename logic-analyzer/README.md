# Basys 3 logic analyzer

This turns a Digilent Basys 3 into an **8-channel logic analyzer** that records up to **100 million samples per second**. You view the recordings in **PulseView** (sigrok) on your Mac, over the board's normal USB cable. Use it to see what's really happening on a wire: Arduino pins, sensor buses, serial ports, I2C, SPI, PWM.

It uses the SUMP / "Openbench Logic Sniffer" protocol, so PulseView treats it as a known device. The whole thing builds with open-source tools on an Apple Silicon Mac. Vivado is not needed.

| | |
|---|---|
| Channels | 8, on Pmod **JB** |
| Sample rate | 100 MHz ÷ n: 100 MHz, 50 MHz, 25 MHz, 20 MHz, 10 MHz … down to about 6 Hz |
| Memory | 131,072 samples, with the pre/post-trigger split set in PulseView |
| Trigger | Up to 4 stages of "these channels high/low". The centre button is a manual "trigger now". |
| Link | USB serial at 921,600 baud. A full 131k capture downloads in about 1.4 s. |
| Self-test | Built-in test signals, either internal (sw0) or on Pmod JC |

## ⚠️ Before you connect anything
- **3.3 V signals only.** The FPGA pins are **not 5 V tolerant**. To probe a 5 V Arduino, put a resistor divider (e.g. 10 kΩ / 20 kΩ) or a level shifter in each line.
- **Always connect ground.** Join the circuit's GND to a JB GND pin (pin 5 or 11).
- Useful bandwidth is about **25 MHz**, since you need at least 4 samples per period, and less with long jumper wires.

## Wiring
```
 Pmod JB (probe inputs)          Pmod JC (test-signal outputs, same layout)
 ┌────┬────┬────┬────┬────┬────┐
 │ 1  │ 2  │ 3  │ 4  │ 5  │ 6  │   top row:    ch0 ch1 ch2 ch3 GND 3V3
 ├────┼────┼────┼────┼────┼────┤
 │ 7  │ 8  │ 9  │ 10 │ 11 │ 12 │   bottom row: ch4 ch5 ch6 ch7 GND 3V3
 └────┴────┴────┴────┴────┴────┘
```
Pin 1 is marked on the board.

## Controls on the board
| | |
|---|---|
| **sw0** up | Sample the built-in test signals instead of JB. No wiring needed. |
| **btnC** (centre) | Manual trigger: start recording now, whatever the trigger condition is |
| **LED0–7** | Live level of each channel |
| **LED12** | Test-signal mode is on |
| **LED13 / 14 / 15** | Armed (waiting for trigger) / triggered (recording) / sending to the PC |
| **7-segment display** | ` rdy` idle · ` Arn` armed · `trig` triggered · `SEnd` sending |

Built-in test signals (on JC, and internally with sw0):

| Channel | Signal |
|---|---|
| ch0 | 1 MHz square wave |
| ch1 | 100 kHz square wave |
| ch2 | 100 kHz PWM whose duty cycle sweeps 0–100 % every 10 ms |
| ch3 | UART at 115,200 baud sending `Hello from Basys3` about every 2.7 ms |
| ch4–7 | 4-bit counter counting at 1 MHz |

## One-time setup (Mac)
1. **Simulation and flashing tools:**
   ```bash
   brew install openfpgaloader icarus-verilog verilator sigrok-cli
   ```
2. **FPGA toolchain** in `~/tools`:
   - openXC7 [release 2026-11-24](https://github.com/cavearr/toolchain-openxc7-releases/releases/tag/2026-11-24), darwin-arm64 package, unpacked to `~/tools/openxc7`.
   - YosysHQ [oss-cad-suite 2026-11-04](https://github.com/YosysHQ/oss-cad-suite-build/releases/tag/2026-11-04), darwin-arm64, unpacked to `~/tools/oss-cad-suite`. This is the Yosys version that openXC7 release was validated with.

   Other locations work: pass `make TOOLS=/path/to/tools …`.
3. **PulseView:** install the macOS DMG from <https://sigrok.org/wiki/Downloads>. It's an Intel build, so it runs under Rosetta.

## Build, load, flash
```bash
make build        # ~15 s, writes build/top.bit
make prog         # load into the FPGA now (lost at power-off)
make flash        # write to the board's flash (kept at power-off)
```
**Close PulseView before `make prog` / `make flash`.** A program holding the serial port can stop openFPGALoader from reaching the USB chip. If it still fails, unplug and replug the board.

For `make flash` to take effect at power-on, the **JP1 jumper** on the Basys 3 must be on **SPI flash** (QSPI), not JTAG.

## First test (no wiring)
1. `make prog`. The display should show ` rdy`.
2. Flip **sw0** up. LED12 lights and LED0–7 flicker with the test signals.
3. Open PulseView:
   1. Click **Connect to Device**.
   2. Driver: **Openbench Logic Sniffer & SUMP compatibles (ols)**.
   3. Interface: **Serial Port**. Pick the port named like `/dev/cu.usbserial-…1`. The board shows up as two ports, and the UART is the one ending in `1`.
   4. Baud rate: **921600**.
   5. Click **Scan for devices using driver above**. It should find **Basys3-LA with 8 channels**.
      - The very first scan after loading the FPGA can fail with "Invalid reply", because the USB chip buffers a stray byte while the FPGA configures. Just scan again.
   6. Instead of sw0, you can also set **Pattern: Internal** in PulseView's device options.
4. Set 1 MHz and 20k samples, then press **Run**.
5. Add a **UART** decoder on channel 3 at 115,200 baud. It should read `Hello from Basys3`.
6. To test the real input path, flip sw0 down and put 8 jumper wires from **JC to JB**, pin for pin. You should see the same signals.

From the command line, the equivalent check is:
```bash
sigrok-cli -d ols:conn=/dev/cu.usbserial-XXXX1:serialcomm=921600/8n1 --scan
```
Then capture and decode channel 3:
```bash
sigrok-cli -d ols:conn=/dev/cu.usbserial-XXXX1:serialcomm=921600/8n1 --config samplerate=1m --samples 20000 -P uart:rx=3:baudrate=115200:format=ascii -A uart=rx-data
```

## Using it
- **Triggers:** in PulseView, click a channel's trigger icon and choose high or low. All channels with a condition must match at the same sample. "Pre-trigger" sets how much of the recording comes before the trigger point.
- Leave all triggers empty to record immediately.
- If nothing happens while it says ` Arn`, the trigger condition never occurred. Press **btnC** to force a capture and see what the signals are actually doing.
- The analyzer only starts looking for the trigger once the pre-trigger part of the buffer is full. So a capture never shows leftovers from an earlier run, but a trigger in the first few moments after you press Run is skipped.

## Verified on the board
With the test signals selected internally, on a Basys 3 driven from macOS by `sigrok-cli` 0.7.2 at 921,600 baud:
- The scan finds "Basys3-LA".
- A UART decode of channel 3 reads "Hello from Basys3".
- A triggered capture puts the trigger at sample 1,000 of 4,000.
- A full 131,072-sample capture at 100 MHz is gap-free across all four RAM banks and downloads in about 1.6 s.

Still untested: probing through the JB pins with external signals, PulseView itself (as opposed to `sigrok-cli`), and booting from flash.

## Tests (no hardware needed)
```bash
make sim          # Icarus Verilog: UART, protocol/trigger/capture, full system over serial
make bridge       # the REAL sigrok driver against the simulated design
```
`make bridge` runs the design in Verilator behind a macOS pseudo-terminal and points `sigrok-cli` at it. It checks three things:
- The device is found as "Basys3-LA".
- A capture decodes the UART test signal as "Hello from Basys3".
- A triggered capture puts the trigger at the right sample.

It also saves `build/bridge_capture.sr`, which you can open in PulseView to see what a capture looks like.

A pseudo-terminal has no modem lines, so `sim/bridge/pty_shim.c` (loaded only into that test's `sigrok-cli`) answers those ioctls the way the real USB port would.

`make flowcheck` builds a tiny toolchain smoke test. After `make flowcheck-prog`:
- LED15 blinks.
- With all switches down, LED0–7 show `10100101` (0xA5), read from block RAM. That confirms RAM contents survive the toolchain.

## How it works
```
 JB pins ─► 2-FF sync ─┐                 ┌──────────── la_core ─────────────┐
                        ├─► sample mux ─►│ capture: divider ► ring buffer    │
 testgen ─► JC pins ────┘   (sw0/flag)   │ (32 block RAMs) ► trigger stages │
                                         │ ► newest-first readback          │
 USB ─► uart_rx ─► sump_cmd (parser) ───►│ config registers                 │
 USB ◄─ uart_tx ◄──────────── tx mux ◄───│ sump_meta (ID "1ALS", metadata)  │
                                         └──────────────────────────────────┘
```
| File | Role |
|---|---|
| `rtl/top.v` | Board pins, synchronisers, power-on reset, LEDs |
| `rtl/la_core.v` | Configuration registers and wiring of the analyzer |
| `rtl/sump_cmd.v` | Splits the byte stream into SUMP commands |
| `rtl/sump_meta.v` | ID and metadata replies |
| `rtl/capture.v` | Sample-rate divider, ring buffer, trigger, readback |
| `rtl/uart_rx.v`, `rtl/uart_tx.v` | Serial link |
| `rtl/testgen.v` | Test signals |
| `rtl/sevenseg.v` | Status display |
| `constraints/basys3.xdc` | Pin assignments (from Digilent's Basys-3-Master.xdc) |

Protocol notes, checked against the libsigrok `openbench-logic-sniffer` driver:
- Command arguments are little-endian. Metadata numbers are big-endian.
- Counts are in units of 4 samples.
- Samples are sent back newest first.
- Memory is reported as 128 KiB. Reporting more than 256 KiB would make sigrok switch to extended commands this design doesn't implement.

## Known limits
- No RLE compression and no 200 MHz "demux" mode. sigrok's own docs call RLE broken on this driver.
- 921,600 baud is verified on macOS with the built-in FTDI driver. Higher rates (2–3 Mbaud) would make big captures download faster, but they are untested. To try it, change `CLKS_PER_BIT` in `rtl/top.v` (e.g. 50 for 2 Mbaud) and set the same baud rate in PulseView.
- openXC7 ignores bitstream compression and fast-flash settings, so booting from flash takes a little longer than a Vivado build. It works the same otherwise.
- Timing comes from nextpnr's estimate (about 168 MHz against the 100 MHz needed). That is not a Vivado signoff, but the margin is large.
