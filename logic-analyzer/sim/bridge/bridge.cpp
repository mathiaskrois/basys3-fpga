// Runs the Verilated analyzer behind a pseudo-terminal so the real sigrok
// "ols" driver can talk to it as if it were the board's serial port.
//
// usage: bridge <file-to-write-pty-path-into>
// Bytes from the pty go into the core one at a time; bytes the core sends go
// back out. Simulated time is not real time, which is fine: sigrok only times
// out on silence after data has started.
#include "Vbridge_top.h"
#include "verilated.h"

#include <cerrno>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <deque>
#include <fcntl.h>
#include <string>
#include <termios.h>
#include <unistd.h>
#include <vector>

static volatile sig_atomic_t stop = 0;
static void on_signal(int) { stop = 1; }

int main(int argc, char **argv) {
    if (argc < 2) { std::fprintf(stderr, "usage: %s <pty-path-file>\n", argv[0]); return 2; }
    std::signal(SIGINT, on_signal);
    std::signal(SIGTERM, on_signal);

    int master = posix_openpt(O_RDWR | O_NOCTTY);
    if (master < 0 || grantpt(master) || unlockpt(master)) { std::perror("pty"); return 1; }
    const char *slave = ptsname(master);
    // Keep one handle on the slave open ourselves so the master never sees
    // EOF/EIO while sigrok opens and closes the port between commands.
    int keep = open(slave, O_RDWR | O_NOCTTY);
    struct termios t;
    tcgetattr(keep, &t); cfmakeraw(&t); tcsetattr(keep, TCSANOW, &t);
    fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK);

    FILE *f = std::fopen(argv[1], "w");
    if (!f) { std::perror(argv[1]); return 1; }
    std::fprintf(f, "%s\n", slave); std::fclose(f);
    std::fprintf(stderr, "bridge: listening on %s\n", slave);

    Verilated::commandArgs(argc, argv);
    Vbridge_top top;
    top.clk = 0; top.rst = 1; top.rx_valid = 0; top.rx_data = 0;
    auto tick = [&]() { top.clk = 1; top.eval(); top.clk = 0; top.eval(); };
    for (int i = 0; i < 20; ++i) tick();
    top.rst = 0;

    std::deque<unsigned char> in;
    std::vector<unsigned char> out;
    unsigned char buf[4096];
    unsigned long long cycles = 0, bytes_in = 0, bytes_out = 0;

    while (!stop) {
        // run a slice of clock cycles
        for (int i = 0; i < 20000; ++i) {
            top.rx_valid = 0;
            if (!in.empty() && (cycles % 4) == 0) {           // one byte per 4 clocks
                top.rx_data = in.front(); in.pop_front(); top.rx_valid = 1;
            }
            tick();
            ++cycles;
            if (top.tx_valid) { out.push_back(top.tx_data); ++bytes_out; }
        }
        // pty I/O
        ssize_t n;
        while ((n = read(master, buf, sizeof buf)) > 0) { in.insert(in.end(), buf, buf + n); bytes_in += n; }
        size_t off = 0;
        while (off < out.size()) {
            ssize_t w = write(master, out.data() + off, out.size() - off);
            if (w <= 0) break;
            off += (size_t)w;
        }
        out.erase(out.begin(), out.begin() + off);
        // idle: nothing to do, no capture running -> don't burn the CPU
        if (in.empty() && out.empty() && top.state == 0) usleep(500);
    }
    std::fprintf(stderr, "bridge: stopped after %llu cycles, %llu bytes in, %llu bytes out\n",
                 cycles, bytes_in, bytes_out);
    close(keep); close(master);
    return 0;
}
