#include "log.h"
#include <stdio.h>
#include <stdarg.h>
#include <time.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <sys/stat.h>

static int log_fd = -1;

void log_init(const char *path) {
    log_fd = open(path, O_CREAT|O_WRONLY|O_APPEND, 0644);
    if (log_fd < 0) {
        // fallback to stdout
        log_fd = 1;
    }
}

static void vlog_emit(const char *lvl, const char *fmt, va_list ap) {
    char ts[32];
    time_t now = time(NULL);
    struct tm tm;
    gmtime_r(&now, &tm);
    strftime(ts, sizeof(ts), "%Y-%m-%dT%H:%M:%SZ", &tm);

    char msg[512];
    vsnprintf(msg, sizeof(msg), fmt, ap);

    char line[640];
    snprintf(line, sizeof(line), "%s [%s] %s\n", ts, lvl, msg);
    write(log_fd, line, strlen(line));
}

void log_info(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    vlog_emit("INFO", fmt, ap);
    va_end(ap);
}

void log_warn(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    vlog_emit("WARN", fmt, ap);
    va_end(ap);
}

void log_error(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    vlog_emit("ERROR", fmt, ap);
    va_end(ap);
}