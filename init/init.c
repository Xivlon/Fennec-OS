#include "log.h"
#include "service.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>
#include <string.h>

static volatile sig_atomic_t shutdown_requested = 0;

static void signal_handler(int sig) {
    if (sig == SIGTERM || sig == SIGINT) {
        shutdown_requested = 1;
    }
}

static void mount_pseudo_filesystems(void) {
    log_info("Mounting pseudo filesystems");
    
    // Mount proc
    if (mount("proc", "/proc", "proc", 0, NULL) < 0) {
        log_error("Failed to mount /proc: %s", strerror(errno));
    }
    
    // Mount sys
    if (mount("sysfs", "/sys", "sysfs", 0, NULL) < 0) {
        log_error("Failed to mount /sys: %s", strerror(errno));
    }
    
    // Mount dev
    if (mount("devtmpfs", "/dev", "devtmpfs", 0, NULL) < 0) {
        log_error("Failed to mount /dev: %s", strerror(errno));
    }
    
    // Mount run
    if (mount("tmpfs", "/run", "tmpfs", 0, "size=10%") < 0) {
        log_error("Failed to mount /run: %s", strerror(errno));
    }
}

static void load_modules(void) {
    log_info("Loading kernel modules");
    
    FILE *f = fopen("/init/config/modules.list", "r");
    if (!f) {
        log_warn("No modules list found at /init/config/modules.list");
        return;
    }
    
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        // Remove newline
        size_t len = strlen(line);
        if (len > 0 && line[len-1] == '\n') {
            line[len-1] = '\0';
        }
        
        // Skip empty lines and comments
        if (line[0] == '\0' || line[0] == '#') {
            continue;
        }
        
        log_info("Loading module: %s", line);
        
        // Use modprobe if available, otherwise insmod
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "modprobe %s 2>/dev/null || insmod %s 2>/dev/null", line, line);
        if (system(cmd) != 0) {
            log_warn("Failed to load module: %s", line);
        }
    }
    
    fclose(f);
}

int main(void) {
    // Initialize logging
    mkdir("/init/logs", 0755);
    log_init("/init/logs/init.log");
    
    log_info("Fennec Init starting (PID 1)");
    
    // Set up signal handlers
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    signal(SIGCHLD, SIG_DFL); // Handle child exits
    
    // Mount pseudo filesystems
    mount_pseudo_filesystems();
    
    // Load kernel modules
    load_modules();
    
    // Load and start services
    log_info("Loading services from /init/config/services");
    int service_count = service_load_dir("/init/config/services");
    log_info("Loaded %d services", service_count);
    
    service_start_initial();
    
    // Main loop - wait for signals and handle service exits
    log_info("Entering main supervision loop");
    while (!shutdown_requested) {
        int status;
        pid_t pid = waitpid(-1, &status, WNOHANG);
        
        if (pid > 0) {
            // A child process exited
            service_handle_exit(pid, status);
        } else if (pid == 0) {
            // No children ready, sleep briefly
            usleep(100000); // 100ms
        } else {
            // Error or no children
            if (errno != ECHILD) {
                log_error("waitpid error: %s", strerror(errno));
            }
            usleep(100000);
        }
    }
    
    log_info("Shutdown requested, stopping services");
    service_stop_all();
    
    log_info("Fennec Init exiting");
    return 0;
}