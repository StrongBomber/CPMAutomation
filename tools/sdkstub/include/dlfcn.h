#ifndef _CPMSTUB_DLFCN_H
#define _CPMSTUB_DLFCN_H
#define RTLD_DEFAULT ((void *)-2)
#define RTLD_LOCAL 0
#define RTLD_LAZY 1
void *dlopen(const char *path, int mode);
void *dlsym(void *handle, const char *symbol);
char *dlerror(void);
int dlclose(void *handle);
#endif
