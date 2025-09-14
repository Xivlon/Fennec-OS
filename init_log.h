#ifndef FENNEC_LOG_H
#define FENNEC_LOG_H
void log_init(const char *path);
void log_info(const char *fmt, ...);
void log_warn(const char *fmt, ...);
void log_error(const char *fmt, ...);
#endif