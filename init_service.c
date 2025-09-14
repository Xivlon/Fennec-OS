#include "service.h"
#include "log.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
#include <dirent.h>

#define MAX_SERVICES 64

typedef struct {
    char name[64];
    char cmd[256];
    char after[128];
    restart_policy_t restart;
    pid_t pid;
    int  started;
} svc_t;

static svc_t services[MAX_SERVICES];
static int service_count = 0;

static restart_policy_t parse_restart(const char *v) {
    if (!v) return RESTART_NO;
    if (strcmp(v, "always") == 0) return RESTART_ALWAYS;
    if (strcmp(v, "on-failure") == 0) return RESTART_ON_FAILURE;
    return RESTART_NO;
}

static void trim(char *s) {
    size_t len = strlen(s);
    while (len && (s[len-1]=='\n' || s[len-1]=='\r')) s[--len]=0;
}

static int parse_service_file(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    svc_t svc;
    memset(&svc, 0, sizeof(svc));
    svc.restart = RESTART_NO;
    char line[512];

    while (fgets(line, sizeof(line), f)) {
        trim(line);
        if (line[0]=='#' || line[0]==0) continue;
        char *eq = strchr(line, '=');
        if (!eq) continue;
        *eq = 0;
        char *key = line;
        char *val = eq + 1;
        if (strcmp(key, "NAME")==0) {
            strncpy(svc.name, val, sizeof(svc.name)-1);
        } else if (strcmp(key, "CMD")==0) {
            strncpy(svc.cmd, val, sizeof(svc.cmd)-1);
        } else if (strcmp(key, "RESTART")==0) {
            svc.restart = parse_restart(val);
        } else if (strcmp(key, "AFTER")==0) {
            strncpy(svc.after, val, sizeof(svc.after)-1);
        }
    }
    fclose(f);
    if (svc.name[0]==0 || svc.cmd[0]==0) {
        log_warn("Invalid service file %s (missing NAME or CMD)", path);
        return -1;
    }
    if (service_count >= MAX_SERVICES) {
        log_error("Service capacity reached; cannot load %s", svc.name);
        return -1;
    }
    services[service_count++] = svc;
    log_info("Loaded service: %s cmd='%s' restart=%d after=%s",
             svc.name, svc.cmd, svc.restart, svc.after[0]?svc.after:"(none)");
    return 0;
}

int service_load_dir(const char *dirpath) {
    DIR *d = opendir(dirpath);
    if (!d) {
        log_warn("Service directory %s not found", dirpath);
        return 0;
    }
    struct dirent *ent;
    while ((ent = readdir(d))) {
        if (ent->d_name[0]=='.') continue;
        char path[512];
        snprintf(path, sizeof(path), "%s/%s", dirpath, ent->d_name);
        parse_service_file(path);
    }
    closedir(d);
    return service_count;
}

static int dependencies_satisfied(svc_t *svc) {
    if (svc->after[0]==0) return 1;
    // simplistic: require that named service is already started
    for (int i=0;i<service_count;i++) {
        if (strcmp(services[i].name, svc->after)==0) {
            return services[i].started;
        }
    }
    // If dependency not found, allow start (or could block)
    return 1;
}

static void spawn_service(svc_t *svc) {
    pid_t pid = fork();
    if (pid == 0) {
        execl("/bin/sh", "sh", "-c", svc->cmd, (char*)NULL);
        log_error("exec failed for %s: %s", svc->name, strerror(errno));
        _exit(127);
    } else if (pid < 0) {
        log_error("fork failed for %s: %s", svc->name, strerror(errno));
        return;
    }
    svc->pid = pid;
    svc->started = 1;
    log_info("Started service %s (pid=%d)", svc->name, pid);
}

void service_start_initial() {
    int progress;
    int started_any = 1;
    // Basic pass-based dependency resolution
    while (started_any) {
        started_any = 0;
        progress = 0;
        for (int i=0;i<service_count;i++) {
            if (!services[i].started && dependencies_satisfied(&services[i])) {
                spawn_service(&services[i]);
                started_any = 1;
            }
        }
        if (++progress > 128) break;
    }
}

void service_handle_exit(pid_t pid, int status) {
    for (int i=0;i<service_count;i++) {
        if (services[i].pid == pid) {
            int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
            log_warn("Service %s (pid=%d) exited status=%d", services[i].name, pid, exit_code);
            int restart = 0;
            if (services[i].restart == RESTART_ALWAYS) restart = 1;
            else if (services[i].restart == RESTART_ON_FAILURE && exit_code != 0) restart = 1;

            if (restart) {
                log_info("Restarting service %s", services[i].name);
                services[i].started = 0;
                spawn_service(&services[i]);
            } else {
                services[i].started = 0;
                services[i].pid = 0;
            }
            return;
        }
    }
}

void service_stop_all() {
    for (int i=0;i<service_count;i++) {
        if (services[i].started && services[i].pid > 1) {
            log_info("Stopping service %s (pid=%d)", services[i].name, services[i].pid);
            kill(services[i].pid, SIGTERM);
        }
    }
    sleep(1);
    for (int i=0;i<service_count;i++) {
        if (services[i].started && services[i].pid > 1) {
            kill(services[i].pid, SIGKILL);
        }
    }
}