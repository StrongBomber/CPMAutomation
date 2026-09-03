#ifndef _CPMSTUB_STDIO_H
#define _CPMSTUB_STDIO_H
#include <stddef.h>
#include <stdarg.h>
typedef struct _CPMFILE FILE;
extern FILE *stdout; extern FILE *stderr;
int printf(const char *fmt, ...) __attribute__((format(printf,1,2)));
int fprintf(FILE *f, const char *fmt, ...) __attribute__((format(printf,2,3)));
int snprintf(char *buf, size_t n, const char *fmt, ...) __attribute__((format(printf,3,4)));
int sscanf(const char *s, const char *fmt, ...);
int puts(const char *s);
#endif
