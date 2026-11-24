# Basys 3 logic analyzer: simulate, build and flash with the open-source openXC7 flow.
#
#   make sim        run all Icarus Verilog testbenches
#   make bridge     run the design in Verilator behind a pseudo-terminal and
#                   point the real sigrok-cli at it (no hardware needed)
#   make build      synthesise, place & route, write build/top.bit
#   make prog       load build/top.bit into the FPGA (lost at power-off)
#   make flash      write build/top.bit to SPI flash (survives power-off)
#   make flowcheck  build the toolchain smoke test (flowcheck/)
#
# Toolchain locations (override on the command line if yours differ):
TOOLS    ?= $(HOME)/tools
OPENXC7  ?= $(TOOLS)/openxc7
YOSYS    ?= $(TOOLS)/oss-cad-suite/bin/yosys
NEXTPNR  ?= $(OPENXC7)/bin/nextpnr-xilinx
FASM2FR  ?= $(OPENXC7)/bin/fasm2frames
FR2BIT   ?= $(OPENXC7)/bin/xc7frames2bit
DB       ?= $(OPENXC7)/share/nextpnr/external/prjxray-db/artix7
LOADER   ?= openFPGALoader

PART     := xc7a35tcpg236-1
RTL      := rtl/uart_rx.v rtl/uart_tx.v rtl/sump_cmd.v rtl/sump_meta.v \
            rtl/capture.v rtl/la_core.v rtl/testgen.v rtl/sevenseg.v rtl/top.v

.SECONDARY:
.PHONY: all sim bridge build prog flash flowcheck flowcheck-prog clean
all: build

# ---------------------------------------------------------------- simulation
sim: build/tb_uart.vvp build/tb_core.vvp build/tb_top.vvp
	@fail=0; for t in uart core top; do \
	    vvp -n build/tb_$$t.vvp > build/tb_$$t.log; \
	    grep -E '^(PASS|FAIL)' build/tb_$$t.log; \
	    grep -q '^PASS' build/tb_$$t.log || fail=1; \
	done; exit $$fail

build/tb_%.vvp: sim/tb_%.v $(RTL)
	@mkdir -p build
	iverilog -g2005 -Wall -Wno-timescale -DSIMULATION -o $@ $< $(RTL)

bridge:
	$(MAKE) -C sim/bridge
	sim/bridge/run_sigrok_test.sh

# ---------------------------------------------------------------- synthesis
build: build/top.bit

build/%.json:
	@mkdir -p build
	$(YOSYS) -q -l build/$*.yosys.log -p "read_verilog $(SRCS_$*); synth_xilinx -flatten -abc9 -arch xc7 -top $*; write_json $@"

build/%.fasm: build/%.json
	$(NEXTPNR) --device $(PART) --json $< -o xdc=$(XDC_$*) -o fasm=$@ \
	    --freq 100 --report build/$*.report.json -l build/$*.pnr.log -q

build/%.frames: build/%.fasm
	$(FASM2FR) --part $(PART) --db-root $(DB) $< > $@

build/%.bit: build/%.frames
	$(FR2BIT) --part_file $(DB)/$(PART)/part.yaml --part_name $(PART) \
	    --frm_file $< --output_file $@
	@echo "Wrote $@"

SRCS_top       := $(RTL)
XDC_top        := constraints/basys3.xdc
SRCS_flowcheck := flowcheck/flowcheck.v
XDC_flowcheck  := flowcheck/flowcheck.xdc
build/top.json:       $(RTL) $(XDC_top)
build/flowcheck.json: flowcheck/flowcheck.v flowcheck/rom.hex flowcheck/flowcheck.xdc

flowcheck: build/flowcheck.bit

# ---------------------------------------------------------------- board
# PulseView must not be running: it attaches to the board's USB chip,
# including the JTAG interface, and openFPGALoader then cannot claim it.
# Closing its window is not enough on macOS; quit it with Cmd+Q.
NO_PULSEVIEW = @if pgrep -q pulseview; then \
    echo "PulseView is running and holds the board's USB connection."; \
    echo "Quit it with Cmd+Q (closing the window is not enough), then retry."; \
    exit 1; fi

prog: build/top.bit
	$(NO_PULSEVIEW)
	$(LOADER) -b basys3 $<

flash: build/top.bit
	$(NO_PULSEVIEW)
	$(LOADER) -b basys3 -f $<

flowcheck-prog: build/flowcheck.bit
	$(NO_PULSEVIEW)
	$(LOADER) -b basys3 $<

clean:
	rm -rf build
	$(MAKE) -C sim/bridge clean
