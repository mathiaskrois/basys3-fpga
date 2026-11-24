#!/usr/bin/env bash
# Points the real sigrok-cli "ols" driver at the Verilated analyzer and checks:
#   1. the device is found and identifies itself as Basys3-LA with 8 channels
#   2. a 1 MHz, 20000-sample capture decodes the built-in UART test signal
#      (channel 3) as "Hello from Basys3"
#   3. a triggered capture (counter on ch4-7 = 10, 25 % pre-trigger) returns
#      4000 samples with the trigger condition at sample 1000
# The capture is also saved as build/bridge_capture.sr, which opens in PulseView.
set -euo pipefail
cd "$(dirname "$0")"
OUT=../../build
mkdir -p "$OUT"
PTYFILE=$(mktemp)
./obj_dir/bridge "$PTYFILE" 2> "$OUT/bridge.log" &
BRIDGE=$!
trap 'kill $BRIDGE 2>/dev/null; wait $BRIDGE 2>/dev/null; rm -f "$PTYFILE"' EXIT
for _ in $(seq 50); do [ -s "$PTYFILE" ] && break; sleep 0.1; done
PTY=$(cat "$PTYFILE")
# The pty ignores the baud rate; 115200 is used because it is a standard macOS
# rate (non-standard rates need an ioctl a pty does not support).
DEV="ols:conn=$PTY:serialcomm=115200/8n1"
# A pty has no modem lines; pty_shim.dylib makes those ioctls succeed so the
# unmodified sigrok driver can open it (test-only, see pty_shim.c).
export DYLD_INSERT_LIBRARIES="$PWD/obj_dir/pty_shim.dylib"
fail=0

echo "== 1. scan"
SCAN=$(sigrok-cli -d "$DEV" --scan 2>&1 || true)
echo "$SCAN"
if echo "$SCAN" | grep -q "Basys3-LA" && echo "$SCAN" | grep -q " 7"; then
    echo "PASS scan: Basys3-LA with channels 0-7"
else
    echo "FAIL scan"; fail=1
fi

echo "== 2. capture + UART decode of channel 3"
DEC=$(sigrok-cli -d "$DEV" --config samplerate=1m --samples 20000 \
        -o "$OUT/bridge_capture.sr" 2>&1 && \
      sigrok-cli -i "$OUT/bridge_capture.sr" -P uart:rx=3:baudrate=115200:format=ascii \
        -A uart=rx-data 2>&1 || true)
TEXT=$(echo "$DEC" | sed -n 's/^uart-1: //p' | tr -d '\n')
echo "decoded: $TEXT"
if echo "$TEXT" | grep -q "Hello from Basys3"; then
    echo "PASS decode: UART test signal reads 'Hello from Basys3'"
else
    echo "$DEC" | head -20; echo "FAIL decode"; fail=1
fi

echo "== 3. triggered capture (counter ch4-7 = 10, 25 % pre-trigger, 10 MHz)"
sigrok-cli -d "$DEV" --config samplerate=10m:captureratio=25 --samples 4000 \
    --triggers 4=0,5=1,6=0,7=1 -O binary > "$OUT/bridge_trigger.bin" 2>/dev/null || true
# sigrok's binary output pads each sample to its unit size; channel 0 is bit 0.
if python3 -I - "$OUT/bridge_trigger.bin" <<'PY'
import sys
d = open(sys.argv[1], 'rb').read()
n = 4000
if len(d) == 0 or len(d) % n:
    sys.exit("got %d bytes, not a multiple of %d samples" % (len(d), n))
u = len(d) // n
ch0 = [d[i * u] & 1 for i in range(n)]
ctr = [d[i * u] >> 4 for i in range(n)]
runs, r = [], 1
for a, b in zip(ch0, ch0[1:]):
    if a == b: r += 1
    else: runs.append(r); r = 1
inner = runs[1:]
print("samples %d, unit size %d, counter at trigger (sample 1000) = %d, ch0 runs %d..%d"
      % (n, u, ctr[1000], min(inner), max(inner)))
ok = ctr[1000] == 10 and set(inner) == {5}
sys.exit(0 if ok else 1)
PY
then echo "PASS trigger: 4000 samples, counter = 10 at the trigger point, 1 MHz square at 10 MHz"
else echo "FAIL trigger"; fail=1; fi

exit $fail
