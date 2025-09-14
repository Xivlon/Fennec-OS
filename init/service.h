#ifndef FENNEC_SERVICE_H
#define FENNEC_SERVICE_H
#include <sys/types.h>

typedef enum {
    RESTART_NO = 0,
    RESTART_ALWAYS = 1,
    RESTART_ON_FAILURE = 2
} restart_policy_t;

int  service_load_dir(const char *dirpath);
void service_start_initial();
void service_handle_exit(pid_t pid, int status);
void service_stop_all();

#endif