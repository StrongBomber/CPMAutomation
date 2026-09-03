#ifndef _CPMSTUB_STDINT_H
#define _CPMSTUB_STDINT_H
#include <stddef.h>
typedef signed char int8_t; typedef unsigned char uint8_t;
typedef short int16_t; typedef unsigned short uint16_t;
typedef int int32_t; typedef unsigned int uint32_t;
typedef long int64_t; typedef unsigned long uint64_t;
typedef long intptr_t; typedef unsigned long uintptr_t;
typedef long long intmax_t; typedef unsigned long long uintmax_t;
#define INT8_MAX 127
#define UINT8_MAX 255
#define INT32_MAX 2147483647
#define UINT32_MAX 4294967295U
#define INT64_MAX 9223372036854775807L
#define INTPTR_MAX 9223372036854775807L
#define PTRDIFF_MAX 9223372036854775807L
#define INTMAX_MIN (-INT64_MAX-1)
#endif
