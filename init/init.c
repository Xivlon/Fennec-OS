#include "service.h"
#include "log.h"
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>
#include <stdlib.h>

static volatile int shutdown_requested = 0;

static void signal_handler(int sig) {
    if (sig == SIGTERM || sig == SIGINT) {
        shutdown_requested = 1;
    }
}

int main() {
    printf("Fennec OS Init System Starting\n");
    
    // Initialize logging
    log_init("/init/logs/init.log");
    log_info("Fennec OS init starting");
    
    // Set up signal handlers
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    
    // Load and start services
    service_load_dir("/init/config/services");
    service_start_initial();
    
    log_info("Initial services started, entering main loop");
    
    // Main event loop
    while (!shutdown_requested) {
        int status;
        pid_t pid = waitpid(-1, &status, WNOHANG);
        
        if (pid > 0) {
            service_handle_exit(pid, status);
        }
        
        sleep(1);
    }
    
    log_info("Shutdown requested, stopping all services");
    service_stop_all();
    
    log_info("Fennec OS init shutting down");
    printf("Fennec OS Init System Shutting Down\n");
    
    return 0;
}