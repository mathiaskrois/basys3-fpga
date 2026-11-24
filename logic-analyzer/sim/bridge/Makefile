# Builds the Verilator model behind the sigrok bridge.
RTL := ../../rtl/uart_tx.v ../../rtl/sump_cmd.v ../../rtl/sump_meta.v \
       ../../rtl/capture.v ../../rtl/la_core.v ../../rtl/testgen.v bridge_top.v

all: obj_dir/bridge obj_dir/pty_shim.dylib

obj_dir/bridge: bridge.cpp $(RTL)
	verilator --cc --exe --build -O2 -Wno-fatal -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
	    --top-module bridge_top -o bridge bridge.cpp $(RTL)

.PHONY: all clean

obj_dir/pty_shim.dylib: pty_shim.c
	@mkdir -p obj_dir
	cc -dynamiclib -O2 -o $@ $<

clean:
	rm -rf obj_dir
