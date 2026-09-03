/* Minimal stddef.h for the offline type-check harness. Not a real SDK. */
#ifndef _CPMSTUB_STDDEF_H
#define _CPMSTUB_STDDEF_H
typedef __signed__ int ptrdiff_t;
typedef unsigned long size_t;
typedef long ssize_t;
typedef int wchar_t;
#ifndef NULL
#define NULL ((void*)0)
#endif
#define offsetof(t, d) __builtin_offsetof(t, d)
#endif
