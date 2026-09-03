#ifndef _CPMSTUB_TIME_H
#define _CPMSTUB_TIME_H
#include <stddef.h>
typedef long time_t; typedef long suseconds_t;
struct timeval { time_t tv_sec; suseconds_t tv_usec; };
struct timespec { time_t tv_sec; long tv_nsec; };
time_t time(time_t *t);
int gettimeofday(struct timeval *tv, void *tz);
clock_t clock(void);
typedef long clock_t;
#endif
