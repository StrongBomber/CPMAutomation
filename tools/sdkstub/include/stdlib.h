#ifndef _CPMSTUB_STDLIB_H
#define _CPMSTUB_STDLIB_H
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
void *malloc(size_t size);
void *calloc(size_t count, size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);
void abort(void) __attribute__((noreturn));
int abs(int);
long labs(long);
double atof(const char *);
long atol(const char *);
long strtol(const char *, char **, int);
unsigned long strtoul(const char *, char **, int);
int rand(void);
void srand(unsigned);
#ifdef __cplusplus
}
#endif
#endif
