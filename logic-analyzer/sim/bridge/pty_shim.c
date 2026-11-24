// Test-only shim, loaded into sigrok-cli with DYLD_INSERT_LIBRARIES by
// run_sigrok_test.sh. A pseudo-terminal has no modem lines and no baud-rate
// hardware, so macOS answers modem-control and IOSSIOSPEED ioctls on it with
// ENOTTY, and libserialport refuses to open it. Here those calls succeed
// instead (as they would on the real FTDI port); every other ioctl, and any
// call on a real device, goes to the system unchanged.
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <IOKit/serial/ioss.h>

static int shim_ioctl(int fd, unsigned long req, ...) {
    va_list ap;
    va_start(ap, req);
    void *arg = va_arg(ap, void *);
    va_end(ap);
    int r = ioctl(fd, req, arg);
    if (r == -1 && errno == ENOTTY) {
        switch (req) {
        case TIOCMGET:
            *(int *)arg = TIOCM_DSR | TIOCM_CTS | TIOCM_CAR | TIOCM_DTR | TIOCM_RTS;
            return 0;
        case TIOCMSET: case TIOCMBIS: case TIOCMBIC:
        case TIOCSDTR: case TIOCCDTR:
        case IOSSIOSPEED:
            return 0;
        default:
            if (getenv("PTY_SHIM_DEBUG")) fprintf(stderr, "pty_shim: ioctl 0x%lx -> ENOTTY\n", req);
            errno = ENOTTY;
        }
    }
    return r;
}

// dyld interposing: replace ioctl in every image except this one.
__attribute__((used)) static struct { const void *replacement, *replacee; } interposers[]
    __attribute__((section("__DATA,__interpose"))) = {
    { (const void *)(unsigned long)&shim_ioctl, (const void *)(unsigned long)&ioctl },
};
