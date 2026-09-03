#ifndef _CPMSTUB_UNISTD_H
#define _CPMSTUB_UNISTD_H
#include <stddef.h>
#include <stdint.h>
typedef unsigned int useconds_t;
typedef int pid_t;
unsigned int sleep(unsigned int);
int usleep(useconds_t);
int nanosleep(const struct timespec *, struct timespec *);
long sysconf(int);
#endif
